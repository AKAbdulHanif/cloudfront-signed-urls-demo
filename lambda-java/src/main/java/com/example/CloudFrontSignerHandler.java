package com.example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.services.ssm.SsmClient;
import software.amazon.awssdk.services.ssm.model.GetParameterRequest;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

import java.io.StringReader;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import org.bouncycastle.util.io.pem.PemObject;
import org.bouncycastle.util.io.pem.PemReader;

/**
 * AWS Lambda handler for generating CloudFront signed URLs.
 * Supports both upload (PUT) and download (GET) operations with key rotation.
 */
public class CloudFrontSignerHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private static final ObjectMapper objectMapper = new ObjectMapper();
    private static final SsmClient ssmClient = SsmClient.builder().build();
    private static final SecretsManagerClient secretsClient = SecretsManagerClient.builder().build();
    private static final DynamoDbClient dynamoDbClient = DynamoDbClient.builder().build();

    // Environment variables
    private static final String CLOUDFRONT_DOMAIN = System.getenv("CLOUDFRONT_DOMAIN");
    private static final String BUCKET_NAME = System.getenv("BUCKET_NAME");
    private static final String TABLE_NAME = System.getenv("TABLE_NAME");
    private static final String UPLOAD_EXPIRATION = System.getenv().getOrDefault("UPLOAD_EXPIRATION", "900");
    private static final String DOWNLOAD_EXPIRATION = System.getenv().getOrDefault("DOWNLOAD_EXPIRATION", "3600");
    private static final String ACTIVE_KEY_ID_PARAM = System.getenv().getOrDefault("ACTIVE_KEY_ID_PARAM", "/cloudfront-signer/active-key-id");
    private static final String ACTIVE_SECRET_ARN_PARAM = System.getenv().getOrDefault("ACTIVE_SECRET_ARN_PARAM", "/cloudfront-signer/active-secret-arn");

    // Cache for active key configuration (5-minute TTL)
    private static final Map<String, CachedKey> keyCache = new ConcurrentHashMap<>();
    private static final long CACHE_TTL_MS = TimeUnit.MINUTES.toMillis(5);

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent input, Context context) {
        context.getLogger().log("Received request: " + input.getPath());

        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        response.setHeaders(getCorsHeaders());

        try {
            String path = input.getPath();
            String httpMethod = input.getHttpMethod();

            if ("OPTIONS".equals(httpMethod)) {
                return response.withStatusCode(200).withBody("");
            }

            if (path.contains("/upload")) {
                return handleUploadRequest(input, context, response);
            } else if (path.contains("/download")) {
                return handleDownloadRequest(input, context, response);
            } else if (path.contains("/files")) {
                return handleListFiles(input, context, response);
            } else {
                return response.withStatusCode(404).withBody("{\"error\":\"Not found\"}");
            }

        } catch (Exception e) {
            context.getLogger().log("Error: " + e.getMessage());
            e.printStackTrace();
            return response.withStatusCode(500)
                    .withBody("{\"error\":\"" + e.getMessage() + "\"}");
        }
    }

    private APIGatewayProxyResponseEvent handleUploadRequest(APIGatewayProxyRequestEvent input, Context context, APIGatewayProxyResponseEvent response) throws Exception {
        Map<String, Object> body = objectMapper.readValue(input.getBody(), Map.class);
        String filename = (String) body.get("filename");
        String contentType = (String) body.getOrDefault("contentType", "application/octet-stream");

        if (filename == null || filename.isEmpty()) {
            return response.withStatusCode(400).withBody("{\"error\":\"filename is required\"}");
        }

        // Generate file ID
        String fileId = UUID.randomUUID().toString();
        String s3Key = "uploads/" + fileId + "/" + filename;

        // Generate signed URL for upload
        String signedUrl = generateSignedUrlForUpload(s3Key, Integer.parseInt(UPLOAD_EXPIRATION));

        // Store metadata in DynamoDB
        storeFileMetadata(fileId, filename, s3Key, contentType);

        Map<String, Object> responseBody = new HashMap<>();
        responseBody.put("fileId", fileId);
        responseBody.put("uploadUrl", signedUrl);
        responseBody.put("filename", filename);
        responseBody.put("expiresIn", UPLOAD_EXPIRATION);

        return response.withStatusCode(200)
                .withBody(objectMapper.writeValueAsString(responseBody));
    }

    private APIGatewayProxyResponseEvent handleDownloadRequest(APIGatewayProxyRequestEvent input, Context context, APIGatewayProxyResponseEvent response) throws Exception {
        String pathParameters = input.getPath();
        String fileId = pathParameters.substring(pathParameters.lastIndexOf("/") + 1);

        // Retrieve metadata from DynamoDB
        Map<String, AttributeValue> item = getFileMetadata(fileId);
        if (item == null) {
            return response.withStatusCode(404).withBody("{\"error\":\"File not found\"}");
        }

        String s3Key = item.get("s3Key").s();
        String filename = item.get("filename").s();

        // Generate signed URL for download
        String signedUrl = generateSignedUrlForDownload(s3Key, Integer.parseInt(DOWNLOAD_EXPIRATION));

        Map<String, Object> responseBody = new HashMap<>();
        responseBody.put("fileId", fileId);
        responseBody.put("downloadUrl", signedUrl);
        responseBody.put("filename", filename);
        responseBody.put("expiresIn", DOWNLOAD_EXPIRATION);

        return response.withStatusCode(200)
                .withBody(objectMapper.writeValueAsString(responseBody));
    }

    private APIGatewayProxyResponseEvent handleListFiles(APIGatewayProxyRequestEvent input, Context context, APIGatewayProxyResponseEvent response) throws Exception {
        ScanRequest scanRequest = ScanRequest.builder()
                .tableName(TABLE_NAME)
                .build();

        ScanResponse scanResponse = dynamoDbClient.scan(scanRequest);
        List<Map<String, Object>> files = new ArrayList<>();

        for (Map<String, AttributeValue> item : scanResponse.items()) {
            Map<String, Object> file = new HashMap<>();
            file.put("fileId", item.get("fileId").s());
            file.put("filename", item.get("filename").s());
            file.put("uploadedAt", item.get("uploadedAt").s());
            files.add(file);
        }

        Map<String, Object> responseBody = new HashMap<>();
        responseBody.put("files", files);

        return response.withStatusCode(200)
                .withBody(objectMapper.writeValueAsString(responseBody));
    }

    private String generateSignedUrlForUpload(String s3Key, int expirationSeconds) throws Exception {
        String url = "https://" + CLOUDFRONT_DOMAIN + "/" + s3Key;
        Instant expiration = Instant.now().plus(expirationSeconds, ChronoUnit.SECONDS);

        // Custom policy for PUT operation
        String policy = String.format(
                "{\"Statement\":[{\"Resource\":\"%s\",\"Condition\":{\"DateLessThan\":{\"AWS:EpochTime\":%d}}}]}",
                url, expiration.getEpochSecond()
        );

        return signUrlWithCustomPolicy(url, policy);
    }

    private String generateSignedUrlForDownload(String s3Key, int expirationSeconds) throws Exception {
        String url = "https://" + CLOUDFRONT_DOMAIN + "/" + s3Key;
        Instant expiration = Instant.now().plus(expirationSeconds, ChronoUnit.SECONDS);

        return signUrlWithCannedPolicy(url, expiration);
    }

    private String signUrlWithCustomPolicy(String url, String policy) throws Exception {
        CachedKey cachedKey = getActiveKey();

        // Base64 encode policy (URL-safe)
        String policyBase64 = Base64.getEncoder().encodeToString(policy.getBytes())
                .replace("+", "-").replace("=", "_").replace("/", "~");

        // Sign the policy
        Signature signature = Signature.getInstance("SHA1withRSA");
        signature.initSign(cachedKey.privateKey);
        signature.update(policy.getBytes());
        byte[] signatureBytes = signature.sign();

        // Base64 encode signature (URL-safe)
        String signatureBase64 = Base64.getEncoder().encodeToString(signatureBytes)
                .replace("+", "-").replace("=", "_").replace("/", "~");

        return url + "?Policy=" + policyBase64 + "&Signature=" + signatureBase64 + "&Key-Pair-Id=" + cachedKey.keyPairId;
    }

    private String signUrlWithCannedPolicy(String url, Instant expiration) throws Exception {
        CachedKey cachedKey = getActiveKey();

        String policy = String.format(
                "{\"Statement\":[{\"Resource\":\"%s\",\"Condition\":{\"DateLessThan\":{\"AWS:EpochTime\":%d}}}]}",
                url, expiration.getEpochSecond()
        );

        // Sign the policy
        Signature signature = Signature.getInstance("SHA1withRSA");
        signature.initSign(cachedKey.privateKey);
        signature.update(policy.getBytes());
        byte[] signatureBytes = signature.sign();

        // Base64 encode signature (URL-safe)
        String signatureBase64 = Base64.getEncoder().encodeToString(signatureBytes)
                .replace("+", "-").replace("=", "_").replace("/", "~");

        return url + "?Expires=" + expiration.getEpochSecond() + "&Signature=" + signatureBase64 + "&Key-Pair-Id=" + cachedKey.keyPairId;
    }

    private CachedKey getActiveKey() throws Exception {
        CachedKey cached = keyCache.get("active");
        if (cached != null && (System.currentTimeMillis() - cached.timestamp) < CACHE_TTL_MS) {
            return cached;
        }

        // Reload from SSM and Secrets Manager
        String keyPairId = ssmClient.getParameter(GetParameterRequest.builder()
                .name(ACTIVE_KEY_ID_PARAM)
                .build()).parameter().value();

        String secretArn = ssmClient.getParameter(GetParameterRequest.builder()
                .name(ACTIVE_SECRET_ARN_PARAM)
                .build()).parameter().value();

        String privateKeyPem = secretsClient.getSecretValue(GetSecretValueRequest.builder()
                .secretId(secretArn)
                .build()).secretString();

        PrivateKey privateKey = loadPrivateKey(privateKeyPem);

        CachedKey newCached = new CachedKey(keyPairId, privateKey, System.currentTimeMillis());
        keyCache.put("active", newCached);

        return newCached;
    }

    private PrivateKey loadPrivateKey(String privateKeyPem) throws Exception {
        PemReader pemReader = new PemReader(new StringReader(privateKeyPem));
        PemObject pemObject = pemReader.readPemObject();
        pemReader.close();

        byte[] keyBytes = pemObject.getContent();
        PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(keyBytes);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        return keyFactory.generatePrivate(spec);
    }

    private void storeFileMetadata(String fileId, String filename, String s3Key, String contentType) {
        Map<String, AttributeValue> item = new HashMap<>();
        item.put("fileId", AttributeValue.builder().s(fileId).build());
        item.put("filename", AttributeValue.builder().s(filename).build());
        item.put("s3Key", AttributeValue.builder().s(s3Key).build());
        item.put("contentType", AttributeValue.builder().s(contentType).build());
        item.put("uploadedAt", AttributeValue.builder().s(Instant.now().toString()).build());

        PutItemRequest request = PutItemRequest.builder()
                .tableName(TABLE_NAME)
                .item(item)
                .build();

        dynamoDbClient.putItem(request);
    }

    private Map<String, AttributeValue> getFileMetadata(String fileId) {
        Map<String, AttributeValue> key = new HashMap<>();
        key.put("fileId", AttributeValue.builder().s(fileId).build());

        GetItemRequest request = GetItemRequest.builder()
                .tableName(TABLE_NAME)
                .key(key)
                .build();

        GetItemResponse response = dynamoDbClient.getItem(request);
        return response.hasItem() ? response.item() : null;
    }

    private Map<String, String> getCorsHeaders() {
        Map<String, String> headers = new HashMap<>();
        headers.put("Access-Control-Allow-Origin", "*");
        headers.put("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        headers.put("Access-Control-Allow-Headers", "Content-Type, Authorization");
        return headers;
    }

    static class CachedKey {
        String keyPairId;
        PrivateKey privateKey;
        long timestamp;

        CachedKey(String keyPairId, PrivateKey privateKey, long timestamp) {
            this.keyPairId = keyPairId;
            this.privateKey = privateKey;
            this.timestamp = timestamp;
        }
    }
}


# DynamoDB Table for File Metadata

resource "aws_dynamodb_table" "main" {
  name           = local.table_name
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "file_id"
  
  attribute {
    name = "file_id"
    type = "S"
  }
  
  # TTL configuration
  ttl {
    enabled        = var.dynamodb_ttl_enabled
    attribute_name = var.dynamodb_ttl_attribute
  }
  
  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  
  # Server-side encryption
  server_side_encryption {
    enabled = true
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-table"
    }
  )
}


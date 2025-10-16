# GitHub Repository Setup Instructions

## Step 1: Create GitHub Repository

1. Go to [GitHub](https://github.com)
2. Click the "+" icon in the top right
3. Select "New repository"
4. Fill in the details:
   - **Repository name**: `cloudfront-signed-urls-demo`
   - **Description**: `AWS CloudFront Signed URLs demo with Terraform, Lambda, and API Gateway`
   - **Visibility**: Choose Public or Private
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
5. Click "Create repository"

## Step 2: Push to GitHub

After creating the repository on GitHub, run these commands:

```bash
cd /home/ubuntu/cloudfront-signed-urls-demo

# Add GitHub remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/cloudfront-signed-urls-demo.git

# Push to GitHub
git push -u origin main
```

## Step 3: Verify

1. Go to your repository on GitHub
2. Verify all files are present
3. Check that README.md is displayed correctly

## Alternative: Using SSH

If you prefer SSH:

```bash
# Add SSH remote
git remote add origin git@github.com:YOUR_USERNAME/cloudfront-signed-urls-demo.git

# Push to GitHub
git push -u origin main
```

## Step 4: Add Repository Topics (Optional)

On GitHub, add these topics to help others discover your repository:
- `aws`
- `cloudfront`
- `terraform`
- `lambda`
- `s3`
- `signed-urls`
- `infrastructure-as-code`
- `serverless`

## Step 5: Enable GitHub Actions (Optional)

GitHub Actions will automatically run Terraform validation on pull requests.

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Enable workflows if prompted

## Troubleshooting

### Authentication Failed

If you get an authentication error:

1. **Using HTTPS**: You may need a Personal Access Token (PAT)
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token with `repo` scope
   - Use the token as your password when pushing

2. **Using SSH**: Ensure your SSH key is added to GitHub
   - Check: `ssh -T git@github.com`
   - Add key: GitHub Settings → SSH and GPG keys

### Remote Already Exists

If you get "remote origin already exists":

```bash
# Remove existing remote
git remote remove origin

# Add new remote
git remote add origin https://github.com/YOUR_USERNAME/cloudfront-signed-urls-demo.git

# Push
git push -u origin main
```

## Next Steps

After pushing to GitHub:

1. Update README.md with your actual repository URL
2. Add repository badges (optional)
3. Enable GitHub Discussions for community support
4. Set up branch protection rules for `main` branch
5. Configure GitHub Pages for documentation (optional)

## Updating the Repository

To push future changes:

```bash
# Make changes to files
# ...

# Stage changes
git add .

# Commit
git commit -m "Description of changes"

# Push
git push
```

## Cloning on Another Machine

To clone your repository on another machine:

```bash
git clone https://github.com/YOUR_USERNAME/cloudfront-signed-urls-demo.git
cd cloudfront-signed-urls-demo
```

---

**Need Help?**

- [GitHub Docs - Adding a local repository to GitHub](https://docs.github.com/en/get-started/importing-your-projects-to-github/importing-source-code-to-github/adding-locally-hosted-code-to-github)
- [GitHub Docs - Authenticating with GitHub](https://docs.github.com/en/authentication)


#!/bin/bash

# Script to push repository to GitHub
# Usage: ./push-to-github.sh YOUR_GITHUB_USERNAME

set -e

if [ -z "$1" ]; then
    echo "Usage: ./push-to-github.sh YOUR_GITHUB_USERNAME"
    echo ""
    echo "Example: ./push-to-github.sh abdulhanif"
    exit 1
fi

GITHUB_USERNAME="$1"
REPO_NAME="cloudfront-signed-urls-demo"

echo "=========================================="
echo "Push to GitHub"
echo "=========================================="
echo ""
echo "GitHub Username: $GITHUB_USERNAME"
echo "Repository: $REPO_NAME"
echo ""

# Check if remote already exists
if git remote get-url origin &> /dev/null; then
    echo "Remote 'origin' already exists:"
    git remote get-url origin
    echo ""
    read -p "Remove and re-add? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote remove origin
    else
        echo "Keeping existing remote. Pushing..."
        git push -u origin main
        exit 0
    fi
fi

# Add remote
echo "Adding GitHub remote..."
git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

echo "Remote added successfully!"
echo ""

# Show what will be pushed
echo "Commits to be pushed:"
git log --oneline
echo ""

# Confirm
read -p "Push to GitHub? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Push cancelled."
    exit 0
fi

# Push
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo "=========================================="
echo "✓ Successfully pushed to GitHub!"
echo "=========================================="
echo ""
echo "Repository URL:"
echo "https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo ""
echo "Next steps:"
echo "1. Go to https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo "2. Add repository topics (aws, cloudfront, terraform, etc.)"
echo "3. Update README.md with your repository URL"
echo "4. Enable GitHub Actions (optional)"
echo "5. Set up branch protection for main branch (optional)"
echo ""


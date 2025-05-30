#!/bin/bash
set -euo pipefail  # Enable strict error handling

# Set Variables
BUCKET_NAME="chijioke-bucket-auto-discovery"
AWS_REGION="eu-west-2"
PROFILE="auto-discovery"

# Function to handle errors
handle_error() {
    echo "❌ Error: $1"
    exit 1
}

# Create S3 Bucket
echo "🚀 Creating S3 bucket: $BUCKET_NAME..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$PROFILE" 2>/dev/null; then
    echo "⚠️  Bucket '$BUCKET_NAME' already exists. Skipping creation."
else
    if ! aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --profile "$PROFILE" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"; then
        handle_error "Failed to create S3 bucket '$BUCKET_NAME'."
    fi
    echo "✅ S3 bucket '$BUCKET_NAME' created successfully."
fi

# Enable versioning
echo "🔄 Enabling versioning for S3 bucket..."
if ! aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$AWS_REGION" \
    --profile "$PROFILE"; then
    handle_error "Failed to enable versioning for S3 bucket '$BUCKET_NAME'."
fi
echo "✅ Versioning enabled successfully."

echo "🎉 S3 Remote State Management Setup Complete!"
echo "🌍 S3 Bucket: $BUCKET_NAME"

# Uncomment if you want to provision Vault and Jenkins automatically
 echo "🚀 Provisioning Vault and Jenkins server..."
 cd ./vault-jenkins

 terraform init 
 terraform fmt --recursive
 terraform validate
 terraform apply -auto-approve
 terraform output
 echo "✅ Vault and Jenkins server provisioned successfully."

#!/bin/bash
set -euo pipefail  # Enable strict error handling

# Set Variables
BUCKET_NAME="team2-bucket-pet-adoption"
AWS_REGION="eu-west-2"
PROFILE="pet-adoption"

# destroy vault and jenkins server
cd ./vault-jenkins
terraform destroy -auto-approve
terraform output

# Function to handle errors
handle_error() {
    echo "❌ Error: $1"
    exit 1
}

# Ensure AWS CLI is installed
if ! command -v aws &>/dev/null; then
    handle_error "AWS CLI is not installed. Please install it and retry."
fi

# Check if S3 bucket exists before attempting deletion
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$PROFILE" 2>/dev/null; then
    echo "🗑️ Deleting all objects from S3 bucket: $BUCKET_NAME..."
    
    # Delete all versions of objects
    versions=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output=json --profile "$PROFILE")
    if [ "$versions" != '{"Objects":[]}' ]; then
        echo "$versions" > delete.json
        if ! aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file://delete.json --profile "$PROFILE"; then
            handle_error "Failed to delete versioned objects from S3 bucket '$BUCKET_NAME'."
        fi
        rm -f delete.json
    fi

    # Delete all delete markers
    delete_markers=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output=json --profile "$PROFILE")
    if [ "$delete_markers" != '{"Objects":[]}' ]; then
        echo "$delete_markers" > delete_markers.json
        if ! aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file://delete_markers.json --profile "$PROFILE"; then
            handle_error "Failed to delete delete markers from S3 bucket '$BUCKET_NAME'."
        fi
        rm -f delete_markers.json
    fi

    echo "✅ All objects, including versioned ones, deleted from S3 bucket."

    echo "🚮 Deleting S3 bucket: $BUCKET_NAME..."
    if ! aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$PROFILE"; then
        handle_error "Failed to delete S3 bucket '$BUCKET_NAME'."
    fi
    echo "✅ S3 bucket '$BUCKET_NAME' deleted successfully."
else
    echo "⚠️  S3 bucket '$BUCKET_NAME' does not exist. Skipping deletion."
fi

echo "🎉 S3 Bucket Cleanup Complete!"
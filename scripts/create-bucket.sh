#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/create-bucket.sh <bucket-name> <aws-region>
# Creates an S3 bucket for static hosting (non-website endpoint, fronted by Cloudflare) with public-read policy.

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <bucket-name> <aws-region>"
  exit 1
fi

BUCKET="$1"
REGION="$2"

# Create bucket (handles us-east-1 separately)
if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
fi

# Enable bucket ownership and ACLs for public read
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
aws s3api put-bucket-ownership-controls --bucket "$BUCKET" --ownership-controls Rules='[{"ObjectOwnership":"ObjectWriter"}]'

# Prepare policy with bucket name
tmp_policy=$(mktemp)
sed "s/BUCKET_NAME_PLACEHOLDER/$BUCKET/g" scripts/policy-public-read.json > "$tmp_policy"

# Attach policy to allow public read of objects
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file://"$tmp_policy"

# Enable versioning
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled

# Enable (optional) static website hosting for index and 404
aws s3 website s3://"$BUCKET"/ --index-document index.html --error-document index.html || true

echo "Bucket $BUCKET created and configured in $REGION."
echo "Website endpoint (if enabled): http://$BUCKET.s3-website-$REGION.amazonaws.com"

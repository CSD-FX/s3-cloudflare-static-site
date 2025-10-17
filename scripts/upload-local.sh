#!/usr/bin/env bash
set -euo pipefail

# Usage: AWS_REGION=us-east-1 S3_BUCKET=my-bucket ./scripts/upload-local.sh
# Syncs local files to S3 with proper cache headers.

: "${AWS_REGION:?Set AWS_REGION}"
: "${S3_BUCKET:?Set S3_BUCKET}"

set -x
aws s3 cp styles.css s3://"$S3_BUCKET"/styles.css --region "$AWS_REGION" \
  --cache-control "public, max-age=31536000, immutable" --content-type text/css
aws s3 cp app.js s3://"$S3_BUCKET"/app.js --region "$AWS_REGION" \
  --cache-control "public, max-age=31536000, immutable" --content-type application/javascript
aws s3 cp index.html s3://"$S3_BUCKET"/index.html --region "$AWS_REGION" \
  --cache-control "no-cache, no-store, must-revalidate" --content-type text/html
set +x

echo "Uploaded to s3://$S3_BUCKET (region $AWS_REGION)."

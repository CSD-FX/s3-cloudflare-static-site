#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/create-cloudfront.sh <bucket-name> <aws-region>
# Creates a CloudFront distribution pointing to the S3 website endpoint (HTTP) with default behaviors.
# Prints the CloudFront domain name.

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <bucket-name> <aws-region>"
  exit 1
fi

BUCKET="$1"
REGION="$2"

WEBSITE_DOMAIN="$BUCKET.s3-website-$REGION.amazonaws.com"

CONFIG=$(cat <<JSON
{
  "CallerReference": "cf-$(date +%s)",
  "Comment": "Static site for $BUCKET",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "s3-website-$BUCKET",
        "DomainName": "$WEBSITE_DOMAIN",
        "OriginPath": "",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {"Quantity": 3, "Items": ["TLSv1", "TLSv1.1", "TLSv1.2"]}
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-website-$BUCKET",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"],
        "CachedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"]
        }
    },
    "Compress": true,
    "ForwardedValues": {
        "QueryString": false,
        "Cookies": {"Forward": "none"}
    },
    "MinTTL": 0,
    "DefaultTTL": 300,
    "MaxTTL": 31536000
  },
  "PriceClass": "PriceClass_100",
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  }
}
JSON
)

RESP=$(aws cloudfront create-distribution --distribution-config "$CONFIG")
DOMAIN=$(echo "$RESP" | jq -r '.Distribution.DomainName')
ID=$(echo "$RESP" | jq -r '.Distribution.Id')

echo "CloudFront distribution created: $ID"
echo "Domain: https://$DOMAIN"
echo "Set GitHub secret CLOUDFRONT_DISTRIBUTION_ID=$ID"

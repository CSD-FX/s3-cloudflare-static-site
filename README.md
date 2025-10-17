# Scalable Static Website with S3 + CloudFront + GitHub Actions (no domain)

This variant uses S3 for storage and CloudFront for global CDN + HTTPS, using the default `*.cloudfront.net` domain (no domain purchase needed). GitHub Actions uploads to S3 and triggers CloudFront invalidation. S3 versioning and correct cache headers are included.

## Repo structure
- `index.html`, `styles.css`, `app.js` – static site
- `.github/workflows/deploy.yml` – CI workflow to upload to S3 and invalidate CloudFront
- `scripts/create-bucket.sh` – create and configure S3 bucket (public read + versioning)
- `scripts/policy-public-read.json` – bucket policy template
- `scripts/upload-local.sh` – manual upload helper
- `scripts/create-cloudfront.sh` – create a CloudFront distribution pointing to the S3 website endpoint

---

# Step-by-step Guide

## 1) AWS CLI (automated)
Requirements: AWS CLI configured (`aws configure`) and IAM user with S3 permissions.
```bash
git clone <your-repo-url> s3-cloudflare-static-site
cd s3-cloudflare-static-site
```
```bash
sudo apt install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
chmod +x ./scripts/create-bucket.sh
sudo ./aws/install
```
```bash
aws configure
```
### Add these
 * AWS Access Key ID [None]: YOUR_ACCESS_KEY
 * AWS Secret Access Key [None]: YOUR_SECRET_KEY
 * Default region name [None]: ap-south-1
 * Default output format [None]: json
   
### Create the s3 bucket
```bash
AWS_REGION=us-east-1
BUCKET=my-unique-bucket-name
./scripts/create-bucket.sh "$BUCKET" "$AWS_REGION"
```
```bash
chmod +x ./scripts/upload-local.sh
# Optional: push initial files with proper cache headers
AWS_REGION=$AWS_REGION S3_BUCKET=$BUCKET ./scripts/upload-local.sh
```

### Then configure the bucket:
- Open the bucket → Permissions tab.
- Under “Bucket policy”, paste this JSON, replacing `BUCKET_NAME`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET_NAME/*"
    }
  ]
}
```
- “Access control list (ACL)”: keep default (objects are readable via the policy above).
- “Bucket Versioning”: enable it (Properties tab → Versioning → Enable).
- “Static website hosting”: Properties tab → Static website hosting → Enable →
  - Index document: `index.html`
  - Error document: `index.html` (single-page-app friendly)
  - Note the “Bucket website endpoint” value; you will use it in Cloudflare CNAME.

What the script does:
- Creates the bucket and turns off public-access blocking for policy use
- Applies a public read bucket policy (objects readable by anyone)
- Enables Versioning
- Enables Static website hosting (index+error = `index.html`) and prints the website endpoint

## 2) CloudFront: create a distribution (HTTPS + CDN)

CloudFront will serve your site over HTTPS at a `https://<random>.cloudfront.net` domain and cache content globally.

Create the distribution pointing to your S3 website endpoint:
```bash
sudo apt install jq -y
# Requirements on your machine: AWS CLI, jq
chmod +x scripts/create-cloudfront.sh
./scripts/create-cloudfront.sh "$S3_BUCKET" "$AWS_REGION"
# Output will include Distribution Id and Domain (copy both)
```
What the script sets:
- Origin: your S3 website endpoint (`http-only` origin policy)
- Viewer protocol policy: `redirect-to-https`
- Allowed methods: GET/HEAD
- Compression: on
- Price class: 100 (North America + Europe; free-tier friendly)

Note: After creation, initial CloudFront deployment takes a few minutes. The script prints the CloudFront domain, e.g. `d123abcd.cloudfront.net`.

## 3) GitHub repository & secrets for CI/CD
Push this repo to GitHub, then add repository secrets (Settings → Secrets and variables → Actions):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (e.g., `us-east-1`)
- `S3_BUCKET` (your bucket name)
- `CLOUDFRONT_DISTRIBUTION_ID` (the Distribution Id printed by `create-cloudfront.sh`)

Workflow `.github/workflows/deploy.yml` on push to `main/master` will:
- inject commit SHA into `app.js`
- upload files to S3 with correct cache headers
- create a CloudFront invalidation for `index.html`, `styles.css`, `app.js`

## 4) Verify end-to-end
- Visit the printed CloudFront domain, e.g., `https://d123abcd.cloudfront.net/`.
- Open DevTools → Network:
  - `server: CloudFront`
  - `via: 1.1 <edge-node> (CloudFront)`
  - `cache-control` headers align with our upload settings

## 5) Rollback
- In S3, enable “Show versions”, select an older version of an object, and “Restore” (or copy that version to the same key).
- Re-run CI or purge Cloudflare cache if necessary.

## 6) Troubleshooting
- **403 AccessDenied (S3)**: ensure public-read bucket policy is attached and public access block is relaxed for the bucket.
- **404 Not Found**: confirm files exist at the bucket root; check S3 website hosting is enabled.
- **Stale content**: re-run CI; CloudFront invalidation may take a few minutes to propagate.

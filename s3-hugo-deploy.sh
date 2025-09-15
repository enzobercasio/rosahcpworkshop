#!/usr/bin/env bash
set -euo pipefail

# ======== Config via ENV (see usage above) =========
: "${BUCKET_NAME:?Set BUCKET_NAME}"
: "${AWS_REGION:?Set AWS_REGION}"
: "${HUGO_SRC:?Set HUGO_SRC}"

INDEX_DOC="index.html"
ERROR_DOC="404.html"
PUBLIC_DIR="${HUGO_SRC}/public"

# ======== Preflight checks =========
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need aws
need hugo

aws sts get-caller-identity >/dev/null # verify AWS creds

# ======== Create bucket if missing =========
echo ">> Ensuring bucket s3://${BUCKET_NAME} exists in ${AWS_REGION}..."
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "   Bucket exists."
else
  if [[ "${AWS_REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi
  echo "   Created."
fi

# ======== Configure static website hosting =========
echo ">> Configuring S3 static website hosting..."
aws s3api put-bucket-website \
  --bucket "${BUCKET_NAME}" \
  --website-configuration "{
    \"IndexDocument\": {\"Suffix\": \"${INDEX_DOC}\"},
    \"ErrorDocument\": {\"Key\": \"${ERROR_DOC}\"}
  }"

# S3 public access settings must allow a public bucket policy
echo ">> Updating Public Access Block (allow public policy reads for website endpoint)..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration '{
    "BlockPublicAcls": false,
    "IgnorePublicAcls": false,
    "BlockPublicPolicy": false,
    "RestrictPublicBuckets": false
  }'

# Optional but typical: enable bucket owner enforced ACLs off (public read via policy is enough)
# (No explicit ACLs needed if policy grants s3:GetObject)

# ======== Attach bucket policy for public read of objects =========
echo ">> Attaching bucket policy to allow public read of site objects..."
POLICY_JSON="$(cat <<POL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForWebsite",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
POL
)"
aws s3api put-bucket-policy --bucket "${BUCKET_NAME}" --policy "${POLICY_JSON}"

# ======== Build Hugo =========
echo ">> Building Hugo site from: ${HUGO_SRC}"
hugo --minify -s "${HUGO_SRC}" -d "public"

# Ensure index and error doc exist (Hugo usually generates index.html; 404 might be 404.html)
if [[ ! -f "${PUBLIC_DIR}/${INDEX_DOC}" ]]; then
  echo "ERROR: ${PUBLIC_DIR}/${INDEX_DOC} not found. Check your Hugo theme/config."
  exit 1
fi
if [[ ! -f "${PUBLIC_DIR}/${ERROR_DOC}" ]]; then
  echo "!! Note: ${ERROR_DOC} not found. Creating a simple 404 page."
  echo '<!doctype html><meta charset="utf-8"><title>404</title><h1>Not Found</h1>' > "${PUBLIC_DIR}/${ERROR_DOC}"
fi

# ======== Deploy (sync) =========
echo ">> Syncing site to s3://${BUCKET_NAME} ..."
# Add sensible Cache-Control (long cache for assets, shorter for HTML)
aws s3 sync "${PUBLIC_DIR}/" "s3://${BUCKET_NAME}/" --delete \
  --exclude "*.html" \
  --metadata-directive REPLACE \
  --cache-control "public, max-age=31536000, immutable"

aws s3 sync "${PUBLIC_DIR}/" "s3://${BUCKET_NAME}/" --delete \
  --exclude "*" --include "*.html" \
  --metadata-directive REPLACE \
  --cache-control "public, max-age=60"

# ======== Output website endpoint =========
echo ">> Done!"
if [[ "${AWS_REGION}" == "us-east-1" ]]; then
  ENDPOINT="http://${BUCKET_NAME}.s3-website-us-east-1.amazonaws.com"
else
  ENDPOINT="http://${BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com"
fi
echo "Website URL: ${ENDPOINT}"

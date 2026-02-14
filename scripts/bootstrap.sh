#!/bin/bash
# scripts/bootstrap.sh
#
# Run this ONCE before the first terraform apply.
# Sets up the GCP project with required APIs and the Terraform state bucket.
#
# Usage: ./scripts/bootstrap.sh <PROJECT_ID>

set -euo pipefail

PROJECT_ID="${1:?Usage: ./scripts/bootstrap.sh <PROJECT_ID>}"
REGION="asia-south1"
STATE_BUCKET="cloudforge-tf-state-${PROJECT_ID}"

echo "🚀 Bootstrapping CloudForge for project: ${PROJECT_ID}"
echo "──────────────────────────────────────────────────────"

# Set project
gcloud config set project "${PROJECT_ID}"

# Enable required APIs
echo "📦 Enabling GCP APIs..."
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  secretmanager.googleapis.com \
  cloudkms.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  dns.googleapis.com \
  binaryauthorization.googleapis.com

echo "✅ APIs enabled"

# Create Terraform state bucket
echo "🪣 Creating Terraform state bucket: ${STATE_BUCKET}"
if gcloud storage buckets describe "gs://${STATE_BUCKET}" &>/dev/null; then
  echo "   Bucket already exists, skipping."
else
  gcloud storage buckets create "gs://${STATE_BUCKET}" \
    --location="${REGION}" \
    --uniform-bucket-level-access \
    --public-access-prevention

  # Enable versioning for state recovery
  gcloud storage buckets update "gs://${STATE_BUCKET}" \
    --versioning

  echo "✅ State bucket created with versioning"
fi

# Set budget alert (optional but recommended)
echo ""
echo "⚠️  IMPORTANT: Set a budget alert in the GCP Console!"
echo "   Go to: Billing → Budgets & alerts → Create budget"
echo "   Set alert at ₹500 ($6) to avoid surprises."
echo ""

echo "──────────────────────────────────────────────────────"
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Update environments/dev/env.hcl with project_id = \"${PROJECT_ID}\""
echo "  2. cd environments/dev/networking && terragrunt init"
echo "  3. terragrunt plan"
echo "  4. terragrunt apply"

# environments/staging/env.hcl
# Staging environment — same project, different resource names.
# In a real org, this would be a separate GCP project.

locals {
  environment = "staging"
  project_id  = "YOUR-GCP-PROJECT-ID"   # ← Same project for cost savings
  region      = "asia-south1"
}

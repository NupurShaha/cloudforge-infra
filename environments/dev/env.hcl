# environments/dev/env.hcl
# Dev environment-specific variables.
# Change project_id to YOUR actual GCP project ID before deploying.

locals {
  environment = "dev"
  project_id  = "bastion-project-409309"   # ← CHANGE THIS
  region      = "asia-south1"            # Mumbai — closest to you in Pune
}

# environments/prod/env.hcl
# Production environment — in a real org, this is a dedicated GCP project
# with stricter IAM, VPC Service Controls, and a separate billing account.

locals {
  environment = "prod"
  project_id  = "bastion-project-409309"   # Separate project in production
  region      = "asia-south1"
}

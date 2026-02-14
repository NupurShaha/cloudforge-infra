# environments/dev/data/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/data/cloud-sql"
}

dependency "networking" {
  config_path = "../networking"
  skip_outputs = true
  mock_outputs = {
    vpc_self_link          = "projects/mock/global/networks/mock"
    private_service_range  = "mock-range"
    data_subnet_self_link  = "projects/mock/regions/asia-south1/subnetworks/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # Cloud SQL — PostgreSQL (cost-optimized for dev)
  instance_name     = "cloudforge-db-dev"
  database_version  = "POSTGRES_15"
  tier              = "db-f1-micro"
  availability_type = "ZONAL"          # No HA in dev
  disk_size         = 10
  disk_type         = "PD_HDD"
  disk_autoresize   = false

  vpc_self_link     = dependency.networking.outputs.vpc_self_link

  # Database
  database_name = "cloudforge"
  db_user       = "cloudforge_app"

  # Backup — minimal in dev
  backup_enabled                  = true
  point_in_time_recovery_enabled  = false
  backup_start_time               = "03:00"
  transaction_log_retention_days  = 1
  retained_backups                = 3

  # Maintenance
  maintenance_day  = 7  # Sunday
  maintenance_hour = 4

  # Dev safety
  deletion_protection = false

  # Memorystore Redis
  redis_name        = "cloudforge-cache-dev"
  redis_tier        = "BASIC"
  redis_memory_gb   = 1
  redis_version     = "REDIS_7_0"

  # Cloud Storage — app assets + backups
  storage_buckets = {
    assets = {
      location      = "asia-south1"
      storage_class = "STANDARD"
      versioning    = false
      lifecycle_age = 30
    }
    db-backups = {
      location      = "asia-south1"
      storage_class = "NEARLINE"
      versioning    = true
      lifecycle_age = 7
    }
  }
}

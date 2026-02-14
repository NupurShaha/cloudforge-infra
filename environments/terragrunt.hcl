# environments/terragrunt.hcl
# Root Terragrunt configuration — all child configs inherit from this.
#
# This file handles:
# 1. Remote state in GCS (auto-generates backend config per module)
# 2. Provider generation (so modules don't hardcode provider blocks)
# 3. Common variables available to all environments

locals {
  # Parse the environment from the folder path
  # e.g., environments/dev/networking → "dev"
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  environment = local.env_vars.locals.environment
  project_id  = local.env_vars.locals.project_id
  region      = local.env_vars.locals.region
}

# ─── Remote State ─────────────────────────────────────────────
# Each module gets its own state file inside a single GCS bucket.
# Path pattern: cloudforge-tf-state/<env>/<module>/terraform.tfstate
remote_state {
  backend = "gcs"
  config = {
    bucket   = "cloudforge-tf-state-${local.project_id}"
    prefix   = "${local.environment}/${path_relative_to_include()}"
    project  = local.project_id
    location = local.region
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ─── Provider Generation ─────────────────────────────────────
# Generates a provider.tf in each module directory so the modules
# themselves stay provider-agnostic and reusable.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.9.0"

      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 6.0"
        }
        google-beta = {
          source  = "hashicorp/google-beta"
          version = "~> 6.0"
        }
      }
    }

    provider "google" {
      project = "${local.project_id}"
      region  = "${local.region}"
    }

    provider "google-beta" {
      project = "${local.project_id}"
      region  = "${local.region}"
    }
  EOF
}

# ─── Common Inputs ────────────────────────────────────────────
# These variables are passed to every module automatically.
inputs = {
  project_id  = local.project_id
  region      = local.region
  environment = local.environment

  # Standard labels applied to all resources
  common_labels = {
    environment = local.environment
    managed_by  = "terraform"
    project     = "cloudforge"
  }
}

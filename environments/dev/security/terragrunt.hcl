# environments/dev/security/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/security/secret-manager"
}

dependency "compute" {
  config_path = "../compute"

  mock_outputs = {
    cluster_name            = "mock-cluster"
    workload_identity_pool  = "mock-project.svc.id.goog"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # Secrets to create
  secrets = {
    redis-auth = {
      description = "Memorystore Redis AUTH token"
    }
    app-secret-key = {
      description = "Application secret key for session encryption"
    }
    api-key-external = {
      description = "External API integration key"
    }
  }

  # KMS keyring for encryption
  kms_keyring_name = "cloudforge-dev-keyring"
  kms_keys = {
    db-encryption = {
      rotation_period = "7776000s"  # 90 days
      purpose         = "ENCRYPT_DECRYPT"
    }
    storage-encryption = {
      rotation_period = "7776000s"
      purpose         = "ENCRYPT_DECRYPT"
    }
  }
}

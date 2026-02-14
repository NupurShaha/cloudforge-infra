# environments/dev/compute/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/compute/gke-cluster"
}

# GKE depends on networking being deployed first
dependency "networking" {
  config_path = "../networking"

  # Mock outputs for `terraform validate` and `plan` when networking hasn't been applied yet
  mock_outputs = {
    vpc_id              = "mock-vpc-id"
    vpc_self_link       = "projects/mock/global/networks/mock"
    app_subnet_name     = "mock-subnet"
    app_subnet_self_link = "projects/mock/regions/asia-south1/subnetworks/mock"
    pods_range_name     = "pods"
    services_range_name = "services"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name = "cloudforge-dev"

  # From networking dependency
  vpc_self_link       = dependency.networking.outputs.vpc_self_link
  subnet_self_link    = dependency.networking.outputs.app_subnet_self_link
  pods_range_name     = dependency.networking.outputs.pods_range_name
  services_range_name = dependency.networking.outputs.services_range_name

  # Private cluster config
  enable_private_nodes    = true
  enable_private_endpoint = false
  master_cidr             = "172.16.0.0/28"

  # Master authorized networks — allow your IP for kubectl
  master_authorized_networks = [
    {
      display_name = "allow-all-temp"
      cidr_block   = "0.0.0.0/0"   # Tighten this in prod!
    }
  ]

  # Node pool — cost-optimized for dev
  node_pools = {
    general = {
      machine_type   = "e2-small"
      spot           = true
      min_count      = 1
      max_count      = 3
      disk_size_gb   = 30
      disk_type      = "pd-standard"
      auto_repair    = true
      auto_upgrade   = true
    }
  }

  # Release channel
  release_channel = "REGULAR"


  # Maintenance window — daily at 4 AM UTC
  maintenance_start_time = "2026-03-01T04:00:00Z"
  maintenance_end_time   = "2026-03-01T08:00:00Z"
  maintenance_recurrence = "FREQ=DAILY"

  # Tenant namespaces to create
  tenant_namespaces = ["tenant-a", "tenant-b", "shared-services"]
}

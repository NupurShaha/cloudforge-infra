# environments/dev/networking/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/networking/vpc"
}

inputs = {
  vpc_name = "cloudforge-vpc"

  subnets = {
    app = {
      cidr   = "10.10.0.0/20"
      region = "asia-south1"
      purpose = "Application workloads (GKE nodes)"
      secondary_ranges = {
        pods     = "10.20.0.0/16"
        services = "10.30.0.0/20"
      }
    }
    data = {
      cidr   = "10.10.16.0/20"
      region = "asia-south1"
      purpose = "Data layer (Cloud SQL, Redis)"
      secondary_ranges = {}
    }
  }

  # Firewall rules
  firewall_rules = {
    allow-internal = {
      direction   = "INGRESS"
      priority    = 1000
      ranges      = ["10.10.0.0/16"]
      protocols   = { tcp = [], udp = [], icmp = [] }
      description = "Allow all internal VPC traffic"
    }
    allow-health-checks = {
      direction   = "INGRESS"
      priority    = 1100
      ranges      = ["35.191.0.0/16", "130.211.0.0/22"]
      protocols   = { tcp = [] }
      description = "Allow GCP health check probes"
    }
    allow-iap-ssh = {
      direction   = "INGRESS"
      priority    = 1200
      ranges      = ["35.235.240.0/20"]
      protocols   = { tcp = ["22"] }
      description = "Allow SSH via IAP tunnel"
    }
  }

  # Cloud NAT
  enable_cloud_nat = true
}

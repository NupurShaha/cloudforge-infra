# environments/dev/observability/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/observability/monitoring"
}

dependency "compute" {
  config_path = "../compute"

  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "data" {
  config_path = "../data"

  mock_outputs = {
    sql_instance_name = "mock-sql"
    redis_instance_id = "mock-redis"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # Notification channels
  notification_email = "your-email@example.com"   # ← CHANGE THIS

  # Alert policies
  alert_policies = {
    gke-high-cpu = {
      display_name = "GKE Node CPU > 80%"
      metric         = "kubernetes.io/node/cpu/allocatable_utilization"
      resource_type = "k8s_node"
      resource_type  = "k8s_node"
      threshold      = 0.8
      duration     = "300s"
      comparison   = "COMPARISON_GT"
    }
    gke-high-memory = {
      display_name = "GKE Node Memory > 85%"
      metric         = "kubernetes.io/node/memory/allocatable_utilization"
      resource_type = "k8s_node"
      resource_type  = "k8s_node"
      threshold      = 0.85
      duration     = "300s"
      comparison   = "COMPARISON_GT"
    }
    sql-high-cpu = {
      display_name = "Cloud SQL CPU > 80%"
      metric         = "cloudsql.googleapis.com/database/cpu/utilization"
      resource_type = "cloudsql_database"
      resource_type  = "cloudsql_database"
      threshold      = 0.8
      duration     = "300s"
      comparison   = "COMPARISON_GT"
    }
    sql-high-connections = {
      display_name = "Cloud SQL Connections > 80% of max"
      metric         = "cloudsql.googleapis.com/database/postgresql/num_backends"
      resource_type = "cloudsql_database"
      resource_type  = "cloudsql_database"
      threshold      = 200
      duration     = "120s"
      comparison   = "COMPARISON_GT"
    }
  }

  # Uptime checks
  uptime_checks = {
    gke-ingress = {
      host    = ""  # Fill after deploying an ingress
      path    = "/healthz"
      period  = "300s"
      timeout = "10s"
    }
  }

  # Log sinks
  log_sinks = {
    audit-to-storage = {
      destination = "storage"
      filter      = "logName:\"cloudaudit.googleapis.com\""
      description = "Export audit logs to GCS for compliance"
    }
  }

  # Log exclusions (cost optimization)
  log_exclusions = {
    exclude-gke-debug = {
      filter      = "resource.type=\"k8s_container\" severity=\"DEBUG\""
      description = "Exclude debug-level container logs to save cost"
    }
  }
}

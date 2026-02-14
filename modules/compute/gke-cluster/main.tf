# modules/compute/gke-cluster/main.tf
#
# Creates a production-grade private GKE cluster with:
# - Private nodes (no public IPs)
# - Workload Identity (keyless pod-to-GCP auth)
# - Network Policy (Calico)
# - Shielded nodes
# - Autoscaling (cluster + node pools)
# - Spot instances (for cost optimization in dev)
# - Maintenance windows
# - Logging and monitoring integration

# ─── Service Account for GKE Nodes ───────────────────────────
# Principle of least privilege: don't use default compute SA
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
  project      = var.project_id
  description  = "Least-privilege SA for GKE nodes. Managed by Terraform."
}

# Grant minimum required roles to the node service account
locals {
  node_sa_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",      # Pull images from Artifact Registry
    "roles/storage.objectViewer",          # Read from GCS (if needed)
  ]
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset(local.node_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ─── GKE Cluster ──────────────────────────────────────────────
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region         # Regional cluster (HA across zones)

  # We manage node pools separately — remove the default pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # ── Networking ──
  network    = var.vpc_self_link
  subnetwork = var.subnet_self_link

  # VPC-native cluster (alias IPs for pods and services)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster — nodes have no public IPs
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_cidr
  }

  # Who can talk to the Kubernetes API
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          display_name = cidr_blocks.value.display_name
          cidr_block   = cidr_blocks.value.cidr_block
        }
      }
    }
  }

  # ── Security ──
  # Workload Identity — THE way to authenticate pods to GCP services
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }


  # Dataplane V2 enables network policy without needing Calico addon
  datapath_provider = "ADVANCED_DATAPATH"

  # Binary Authorization — require signed images (attestation)
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # ── Operations ──
  release_channel {
    channel = var.release_channel
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  # Logging and monitoring — use Cloud Operations
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # ── Addons ──
  addons_config {
    http_load_balancing {
      disabled = false     # Enable GCP Ingress controller
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true       # Use CSI driver for persistent disks
    }
    dns_cache_config {
      enabled = true       # NodeLocal DNSCache for performance
    }
  }

  # Cluster autoscaling (scales node count across pools)
  cluster_autoscaling {
    enabled = true
    resource_limits {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 12
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 2
      maximum       = 48
    }
    auto_provisioning_defaults {
      service_account = google_service_account.gke_nodes.email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

      management {
        auto_repair  = true
        auto_upgrade = true
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }

  resource_labels = merge(var.common_labels, {
    cluster = var.cluster_name
  })

  # Protect against accidental deletion in prod
  deletion_protection = var.environment == "prod" ? true : false

  lifecycle {
    ignore_changes = [
      # Node count changes via autoscaler — don't revert
      initial_node_count,
    ]
  }

  depends_on = [
    google_project_iam_member.gke_node_roles,
  ]
}

# ─── Node Pools ───────────────────────────────────────────────
# Using for_each to create multiple node pools from a single variable
resource "google_container_node_pool" "pools" {
  for_each = var.node_pools

  name     = "${var.cluster_name}-${each.key}"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.primary.name

  # Autoscaling config
  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  node_config {
    machine_type    = each.value.machine_type
    spot            = each.value.spot
    disk_size_gb    = each.value.disk_size_gb
    disk_type       = each.value.disk_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded VM — secure boot + integrity monitoring
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Labels on the nodes
    labels = merge(var.common_labels, each.value.labels, {
      pool = each.key
    })

    # Taints (e.g., for dedicated GPU or high-memory pools)
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    tags = ["gke-node", "${var.environment}-${var.cluster_name}"]
  }

  lifecycle {
    create_before_destroy = true   # Zero-downtime node pool updates
    ignore_changes = [
      # Autoscaler manages node count
      initial_node_count,
    ]
  }
}

# ─── Kubernetes Provider Config ───────────────────────────────
# Configure the Kubernetes provider using the cluster credentials
data "google_client_config" "default" {}

# ─── Namespaces for Multi-Tenancy ─────────────────────────────
# Creates isolated namespaces per tenant
resource "google_project_iam_custom_role" "namespace_viewer" {
  count = length(var.tenant_namespaces) > 0 ? 1 : 0

  role_id     = replace("cloudforge_${var.environment}_ns_viewer", "-", "_")
  title       = "CloudForge Namespace Viewer (${var.environment})"
  description = "Read-only access to tenant namespaces"
  project     = var.project_id
  permissions = [
    "container.pods.get",
    "container.pods.list",
    "container.services.get",
    "container.services.list",
  ]
}

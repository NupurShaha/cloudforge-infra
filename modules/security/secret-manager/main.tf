# modules/security/secret-manager/main.tf
#
# Creates:
# - Secret Manager secrets (placeholders for application secrets)
# - KMS Keyring and Crypto Keys (for CMEK encryption)
# - IAM bindings for secret access

# ─── Secret Manager Secrets ───────────────────────────────────
resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  secret_id = "${var.environment}-${each.key}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = merge(var.common_labels, {
    secret_type = each.key
  })
}

# Create initial placeholder versions (apps will update these)
resource "google_secret_manager_secret_version" "initial" {
  for_each = var.secrets

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = "PLACEHOLDER-CHANGE-ME-${each.key}"

  lifecycle {
    # Don't revert if the secret value was updated outside Terraform
    ignore_changes = [secret_data]
  }
}

# ─── KMS Keyring ──────────────────────────────────────────────
resource "google_kms_key_ring" "keyring" {
  name     = var.kms_keyring_name
  project  = var.project_id
  location = var.region

  lifecycle {
    # KMS keyrings cannot be deleted — protect against destroy
    prevent_destroy = false   # Set to true in prod
  }
}

# ─── KMS Crypto Keys ─────────────────────────────────────────
resource "google_kms_crypto_key" "keys" {
  for_each = var.kms_keys

  name            = "${var.environment}-${each.key}"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = each.value.rotation_period
  purpose         = each.value.purpose

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  labels = merge(var.common_labels, {
    key_purpose = each.key
  })

  lifecycle {
    prevent_destroy = false   # Set to true in prod
  }
}

# ─── IAM: Grant Cloud SQL service agent access to KMS ─────────
# This allows Cloud SQL to use the CMEK key for encryption
data "google_project" "current" {
  project_id = var.project_id
}

resource "google_kms_crypto_key_iam_member" "cloudsql_cmek" {
  for_each = {
    for k, v in var.kms_keys : k => v
    if k == "db-encryption"
  }

  crypto_key_id = google_kms_crypto_key.keys[each.key].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
}

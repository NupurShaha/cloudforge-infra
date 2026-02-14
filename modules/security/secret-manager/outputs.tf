# modules/security/secret-manager/outputs.tf

output "secret_ids" {
  description = "Map of secret name to Secret Manager secret ID"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.secret_id }
}

output "secret_names" {
  description = "Map of secret name to full resource name"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.name }
}

output "kms_keyring_id" {
  description = "KMS Keyring ID"
  value       = google_kms_key_ring.keyring.id
}

output "kms_key_ids" {
  description = "Map of KMS key name to key ID"
  value       = { for k, v in google_kms_crypto_key.keys : k => v.id }
}

# policies/opa/deny_public_buckets.rego
#
# Policy: No GCS bucket may have public access enabled.
# Enforced in CI pipeline via conftest before terraform apply.

package cloudforge.gcs

import rego.v1

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    resource.change.after.public_access_prevention != "enforced"
    msg := sprintf(
        "GCS bucket '%s' must have public_access_prevention = 'enforced'. Public buckets are not allowed.",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    resource.change.after.uniform_bucket_level_access != true
    msg := sprintf(
        "GCS bucket '%s' must enable uniform_bucket_level_access.",
        [resource.address]
    )
}

# policies/opa/require_labels.rego
#
# Policy: All resources must have 'environment' and 'managed_by' labels.
# Ensures cost tracking and ownership are always in place.

package cloudforge.labels

import rego.v1

required_labels := {"environment", "managed_by"}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    labels := object.get(resource.change.after, "labels", {})
    labels != null
    missing := required_labels - {key | labels[key]}
    count(missing) > 0
    msg := sprintf(
        "Resource '%s' is missing required labels: %v",
        [resource.address, missing]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    labels := object.get(resource.change.after, "resource_labels", {})
    labels != null
    missing := required_labels - {key | labels[key]}
    count(missing) > 0
    msg := sprintf(
        "Resource '%s' is missing required resource_labels: %v",
        [resource.address, missing]
    )
}

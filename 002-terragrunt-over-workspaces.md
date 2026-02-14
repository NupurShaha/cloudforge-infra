# ADR-002: Terragrunt Over Terraform Workspaces

## Status
Accepted

## Context
We need to manage 3 environments (dev, staging, prod) with the same Terraform modules but different configurations. Two common approaches exist: Terraform workspaces and Terragrunt.

## Decision
We chose **Terragrunt** for multi-environment management.

## Rationale
- **State isolation**: Each environment/layer gets its own state file. Workspaces share a backend, risking accidental cross-environment changes.
- **DRY configuration**: Terragrunt's `include` and `dependency` blocks eliminate copy-paste between environments. Only differences are specified per-env.
- **Dependency management**: Terragrunt understands cross-module dependencies (networking → compute → data) and applies them in order.
- **Provider generation**: Root `terragrunt.hcl` generates provider blocks, so modules stay provider-agnostic and reusable.
- **Blast radius**: A mistake in dev cannot affect prod state because they are completely separate state files.

## Trade-off
- Additional tool to install and learn
- Terragrunt's caching (`.terragrunt-cache/`) can be confusing initially
- Some CI/CD tools have better native Terraform support than Terragrunt support

## Consequences
- All team members must have Terragrunt installed
- CI pipeline uses `terragrunt run-all plan/apply` instead of raw Terraform
- Module development still uses pure Terraform — Terragrunt is only the orchestration layer

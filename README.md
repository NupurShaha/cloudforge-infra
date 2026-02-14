# CloudForge — Production-Grade Multi-Tenant SaaS Infrastructure on GCP

> Fully automated, modular Terraform infrastructure for deploying a multi-tenant SaaS platform on Google Cloud Platform. Designed with production patterns: private networking, zero-trust security, observability, cost optimization, and cross-region disaster recovery.

## Architecture

```
                              ┌─────────────────────────────┐
                              │       Cloud Armor (WAF)      │
                              │   DDoS · Rate Limit · OWASP  │
                              └──────────┬──────────────────┘
                                         │
                              ┌──────────▼──────────────────┐
                              │   Global HTTPS Load Balancer  │
                              │       (SSL Termination)       │
                              └──────────┬──────────────────┘
                                         │
  ┌──────────────────────────────────────▼────────────────────────────────────┐
  │                        VPC (Private Network)                              │
  │                                                                           │
  │  ┌─────────────────────────────────────────────────────────┐             │
  │  │              GKE Private Cluster                         │             │
  │  │  ┌──────────┐ ┌──────────┐ ┌───────────────┐           │             │
  │  │  │ Tenant A │ │ Tenant B │ │ Shared Svcs   │           │             │
  │  │  │ (namespace)│(namespace)│ │ (namespace)    │           │             │
  │  │  └──────────┘ └──────────┘ └───────────────┘           │             │
  │  │  • Workload Identity  • Spot Instances  • Autoscaling   │             │
  │  │  • Network Policy     • Shielded Nodes  • Binary Auth   │             │
  │  └─────────────────────────────────────────────────────────┘             │
  │                          │                    │                           │
  │               ┌──────────▼─────┐    ┌────────▼──────────┐               │
  │               │  Cloud SQL     │    │  Memorystore      │               │
  │               │  PostgreSQL 15 │    │  Redis 7.0        │               │
  │               │  (Private IP)  │    │  (AUTH enabled)   │               │
  │               │  Auto-backup   │    │  Private access   │               │
  │               └────────────────┘    └───────────────────┘               │
  │                                                                           │
  │  Cloud NAT (outbound) ──►  Internet                                      │
  └───────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────────────────┐
  │  Secret Manager  │  │  Cloud KMS       │  │  Cloud Monitoring           │
  │  (App secrets)   │  │  (CMEK keys)     │  │  Dashboards · Alerts · SLOs │
  └─────────────────┘  └──────────────────┘  └─────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────────┐
  │  DR Region (asia-south2) — IaC Ready                                     │
  │  • Standby VPC + GKE  • SQL cross-region replica  • DNS failover        │
  └──────────────────────────────────────────────────────────────────────────┘
```

## What This Provisions

| Layer | Resources | Status |
|-------|-----------|--------|
| **Networking** | VPC, Subnets (app + data), Private Service Access, Firewall Rules, Cloud NAT, Cloud Router | ✅ Deployed |
| **Compute** | Private GKE Cluster, Spot Node Pools, Workload Identity, Cluster Autoscaling | ✅ Deployed |
| **Data** | Cloud SQL PostgreSQL (private IP, backups), Memorystore Redis (AUTH), GCS Buckets | ✅ Deployed |
| **Security** | Secret Manager, Cloud KMS (CMEK), OPA Policies, IAM (least privilege) | ✅ Deployed |
| **Observability** | Cloud Monitoring Dashboards, Alert Policies, Log Sinks, Log Exclusions | ✅ Deployed |
| **CI/CD** | GitHub Actions (fmt, validate, tflint, tfsec, OPA), Workload Identity Federation | ✅ Configured |
| **DR** | Secondary VPC, Cross-region SQL Replica, DNS Failover | 📝 IaC Ready |

## Module Catalog

```
modules/
├── networking/vpc/           # VPC, subnets, firewall, NAT, private service access
├── compute/gke-cluster/      # Private GKE with node pools, Workload Identity
├── data/cloud-sql/           # Cloud SQL, Memorystore Redis, GCS buckets
├── security/secret-manager/  # Secret Manager + Cloud KMS
├── observability/monitoring/ # Dashboards, alerts, log sinks, exclusions
├── cicd/                     # Cloud Build, Workload Identity Federation
└── dr/                       # DR network, database replica, DNS failover
```

## Multi-Environment Management

Environments are managed via [Terragrunt](https://terragrunt.gruntwork.io/), providing DRY configuration with complete state isolation:

```
environments/
├── terragrunt.hcl        # Root config (remote state, provider generation)
├── dev/                   # ✅ Validated and deployed
│   ├── networking/
│   ├── compute/
│   ├── data/
│   ├── security/
│   └── observability/
├── staging/               # 📝 Config ready (same modules, different params)
└── prod/                  # 📝 Config ready (HA, larger instances, DR enabled)
    └── dr/
```

## Quick Start

```bash
# 1. Bootstrap (one-time)
./scripts/bootstrap.sh YOUR-PROJECT-ID

# 2. Update project ID
vim environments/dev/env.hcl

# 3. Deploy networking
cd environments/dev/networking && terragrunt apply

# 4. Deploy compute (GKE)
cd ../compute && terragrunt apply

# 5. Deploy data layer
cd ../data && terragrunt apply

# 6. Deploy security
cd ../security && terragrunt apply

# 7. Deploy observability
cd ../observability && terragrunt apply

# Or deploy everything at once:
cd environments/dev && terragrunt run-all apply
```

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Cluster type | Private GKE | No public IPs on nodes, reduced attack surface |
| Node instances | Spot (dev), On-demand (prod) | 60-91% cost savings in non-prod |
| Database access | Private IP only | No public exposure, VPC peering |
| Pod auth to GCP | Workload Identity | Keyless, no service account JSON keys |
| Env management | Terragrunt | State isolation, DRY config, dependency ordering |
| Policy enforcement | OPA/Conftest | Shift-left security, fail before apply |
| CI auth to GCP | Workload Identity Federation | Keyless GitHub Actions → GCP |
| DR strategy | Cross-region replica + DNS failover | RTO < 15min, RPO ~seconds |

See [Architecture Decision Records](./docs/adr/) for detailed rationale.

## Cost Optimization

Dev environment runs at **~$0.17/hour** using:
- Spot instances for GKE nodes (60-91% cheaper)
- `db-f1-micro` for Cloud SQL (smallest tier)
- Basic tier Redis (no HA replica)
- `pd-standard` disks (not SSD)
- Log exclusions to reduce Cloud Logging costs
- `terraform destroy` for ephemeral environments

## CI Pipeline

Every PR triggers: `format check → validate → tflint → tfsec → OPA policy check`

## Tools

| Tool | Purpose |
|------|---------|
| Terraform >= 1.9 | Infrastructure as Code |
| Terragrunt >= 0.68 | Multi-environment orchestration |
| tflint | Terraform linting |
| tfsec / Trivy | Security scanning |
| Conftest + OPA | Policy-as-Code enforcement |
| terraform-docs | Auto-generated module documentation |
| pre-commit | Git hooks for quality gates |

## License

MIT

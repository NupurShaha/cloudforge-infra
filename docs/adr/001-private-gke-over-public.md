# ADR-001: Private GKE Cluster Over Public

## Status
Accepted

## Context
We need to deploy a GKE cluster for the CloudForge SaaS platform. GKE supports both public clusters (nodes and API server have public IPs) and private clusters (nodes have only private IPs, API server optionally private).

## Decision
We chose **private GKE clusters** with public API endpoint (restricted by authorized networks) for all environments.

## Rationale
- **Security**: Nodes with no public IPs cannot be directly reached from the internet, significantly reducing attack surface
- **Compliance**: SOC2 and ISO 27001 require minimizing public-facing infrastructure
- **Cost**: No public IP charges on nodes
- **Egress control**: All outbound traffic routes through Cloud NAT, enabling logging and control
- **Trade-off**: Requires Cloud NAT for outbound (image pulls, API calls) — small cost (~$0.045/hr) but worth the security benefit

## Consequences
- Must provision Cloud NAT in each environment
- Container image pulls route through NAT (slightly slower, negligible in practice)
- SSH access to nodes only via IAP tunnels (not direct SSH)
- Private endpoint mode (for prod) requires a bastion or VPN for kubectl access

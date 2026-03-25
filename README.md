# GCP Network Infrastructure — Terraform

Hands-on Terraform projects provisioning Google Cloud Platform 
networking infrastructure. Built as part of a practical GCP 
cloud networking study path (2026).

---

## Project 1 — Custom VPC with Subnets, Firewall & VMs

**Path:** `project-1-basic-vpc/`

Provisions a custom-mode VPC network with:
- 3 subnets in non-overlapping CIDR ranges across multiple zones
- Firewall rules allowing ICMP and SSH
- 3 Compute Engine VMs (one per subnet)

**Technologies:** Terraform, GCP Compute Engine, VPC Networking

---

## Project 2 — HA VPN with Dynamic BGP Routing (Multi-Project)

**Path:** `project-2-ha-vpn-bgp/`

Provisions a redundant site-to-site VPN between two isolated 
GCP projects using:
- HA VPN Gateways (99.99% SLA, 2 tunnels per side)
- Cloud Routers with eBGP sessions (unique ASNs per side)
- Dynamic route exchange via BGP — automatic failover
- Multi-provider Terraform configuration (two GCP projects 
  in a single codebase)

**Technologies:** Terraform, GCP HA VPN, Cloud Router, BGP, 
Multi-provider setup

---

## Usage

1. Clone the repository
2. Navigate to the project folder
3. Copy `terraform.tfvars.example` to `terraform.tfvars` 
   and fill in your project IDs and secrets
4. Run:
```bash
terraform init
terraform plan
terraform apply
```

> **Note:** Never commit `terraform.tfvars` or `*.tfstate` 
> files — they are excluded via `.gitignore`.

---

## Author

Tomasz Kurpiś — linkedin.com/in/tomaszkurpis
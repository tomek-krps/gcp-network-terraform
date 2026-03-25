terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.25.0"
    }
  }
}

# ============================================================
# PROVIDER CONFIGURATION
# Two providers with aliases allow managing two separate GCP
# projects within a single Terraform codebase — mirroring
# real-world enterprise network isolation patterns.
# ============================================================

provider "google" {
  alias   = "project_a"
  project = var.project_a_id
  region  = var.region
}

provider "google" {
  alias   = "project_b"
  project = var.project_b_id
  region  = var.region
}

# ============================================================
# PROJECT A — VPC, Subnet, Firewall, VM
# Network: 10.1.0.0/24
# ============================================================

resource "google_compute_network" "vpc_a" {
  provider                = google.project_a
  name                    = "vpc-project-a"
  auto_create_subnetworks = false
  # GLOBAL routing mode allows Cloud Routers to learn routes
  # from all regions — required for multi-region HA VPN setups
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "subnet_a" {
  provider      = google.project_a
  name          = "subnet-project-a"
  ip_cidr_range = "10.1.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_a.id
}

# Firewall rule: allow ICMP and SSH only from known internal ranges
# (both VPC subnets) — traffic is not exposed to the public internet
resource "google_compute_firewall" "firewall_a" {
  provider = google.project_a
  name     = "allow-internal-ssh-icmp-a"
  network  = google_compute_network.vpc_a.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.1.0.0/24", "10.2.0.0/24"]
}

resource "google_compute_instance" "vm_a" {
  provider     = google.project_a
  name         = "vm-project-a"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_a.id
    subnetwork = google_compute_subnetwork.subnet_a.id
    access_config {}
  }
}

# ============================================================
# PROJECT B — VPC, Subnet, Firewall, VM
# Network: 10.2.0.0/24
# ============================================================

resource "google_compute_network" "vpc_b" {
  provider                = google.project_b
  name                    = "vpc-project-b"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "subnet_b" {
  provider      = google.project_b
  name          = "subnet-project-b"
  ip_cidr_range = "10.2.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_b.id
}

resource "google_compute_firewall" "firewall_b" {
  provider = google.project_b
  name     = "allow-internal-ssh-icmp-b"
  network  = google_compute_network.vpc_b.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.1.0.0/24", "10.2.0.0/24"]
}

resource "google_compute_instance" "vm_b" {
  provider     = google.project_b
  name         = "vm-project-b"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_b.id
    subnetwork = google_compute_subnetwork.subnet_b.id
    access_config {}
  }
}

# ============================================================
# PROJECT A — HA VPN Gateway + Cloud Router
#
# HA VPN automatically provisions two public IP interfaces
# (interface 0 and interface 1), enabling redundant tunnels
# and a 99.99% availability SLA.
# ============================================================

resource "google_compute_ha_vpn_gateway" "ha_vpn_gw_a" {
  provider = google.project_a
  name     = "ha-vpn-gateway-project-a"
  network  = google_compute_network.vpc_a.id
  region   = var.region
}

resource "google_compute_router" "router_a" {
  provider = google.project_a
  name     = "cloud-router-project-a"
  network  = google_compute_network.vpc_a.id
  region   = var.region

  bgp {
    asn = var.asn_project_a
  }
}

# ============================================================
# PROJECT B — HA VPN Gateway + Cloud Router
# ============================================================

resource "google_compute_ha_vpn_gateway" "ha_vpn_gw_b" {
  provider = google.project_b
  name     = "ha-vpn-gateway-project-b"
  network  = google_compute_network.vpc_b.id
  region   = var.region
}

resource "google_compute_router" "router_b" {
  provider = google.project_b
  name     = "cloud-router-project-b"
  network  = google_compute_network.vpc_b.id
  region   = var.region

  bgp {
    asn = var.asn_project_b
  }
}

# ============================================================
# HA VPN TUNNELS
#
# HA VPN requires two tunnels for redundancy — one per gateway
# interface. Each tunnel maps interface 0 on side A to
# interface 0 on side B, and interface 1 to interface 1.
# This provides tunnel-level failover with automatic BGP
# reconvergence if one tunnel goes down.
# ============================================================

# Tunnel 1: Project A (interface 0) → Project B (interface 0)
resource "google_compute_vpn_tunnel" "tunnel_a_to_b_0" {
  provider              = google.project_a
  name                  = "tunnel-a-to-b-0"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_vpn_gw_a.id
  vpn_gateway_interface = 0
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_vpn_gw_b.id
  shared_secret         = "REPLACE_WITH_STRONG_SECRET"
  router                = google_compute_router.router_a.id
}

# Tunnel 2: Project A (interface 1) → Project B (interface 1)
resource "google_compute_vpn_tunnel" "tunnel_a_to_b_1" {
  provider              = google.project_a
  name                  = "tunnel-a-to-b-1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_vpn_gw_a.id
  vpn_gateway_interface = 1
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_vpn_gw_b.id
  shared_secret         = "REPLACE_WITH_STRONG_SECRET"
  router                = google_compute_router.router_a.id
}

# Tunnel 3: Project B (interface 0) → Project A (interface 0)
resource "google_compute_vpn_tunnel" "tunnel_b_to_a_0" {
  provider              = google.project_b
  name                  = "tunnel-b-to-a-0"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_vpn_gw_b.id
  vpn_gateway_interface = 0
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_vpn_gw_a.id
  shared_secret         = "REPLACE_WITH_STRONG_SECRET"
  router                = google_compute_router.router_b.id
}

# Tunnel 4: Project B (interface 1) → Project A (interface 1)
resource "google_compute_vpn_tunnel" "tunnel_b_to_a_1" {
  provider              = google.project_b
  name                  = "tunnel-b-to-a-1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_vpn_gw_b.id
  vpn_gateway_interface = 1
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_vpn_gw_a.id
  shared_secret         = "REPLACE_WITH_STRONG_SECRET"
  router                = google_compute_router.router_b.id
}

# ============================================================
# BGP — Router interfaces and peers for Project A
#
# Each tunnel gets a dedicated BGP interface using a link-local
# address from the 169.254.0.0/16 range).
# The /30 subnet provides exactly two usable IPs per tunnel:
#   .1 = local interface, .2 = remote peer
# ============================================================

resource "google_compute_router_interface" "router_interface_a_0" {
  provider   = google.project_a
  name       = "bgp-interface-a-0"
  router     = google_compute_router.router_a.name
  region     = var.region
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_a_to_b_0.name
}

resource "google_compute_router_peer" "bgp_peer_a_0" {
  provider        = google.project_a
  name            = "bgp-peer-a-0"
  router          = google_compute_router.router_a.name
  region          = var.region
  peer_ip_address = "169.254.0.2"
  peer_asn        = var.asn_project_b
  interface       = google_compute_router_interface.router_interface_a_0.name
}

resource "google_compute_router_interface" "router_interface_a_1" {
  provider   = google.project_a
  name       = "bgp-interface-a-1"
  router     = google_compute_router.router_a.name
  region     = var.region
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_a_to_b_1.name
}

resource "google_compute_router_peer" "bgp_peer_a_1" {
  provider        = google.project_a
  name            = "bgp-peer-a-1"
  router          = google_compute_router.router_a.name
  region          = var.region
  peer_ip_address = "169.254.1.2"
  peer_asn        = var.asn_project_b
  interface       = google_compute_router_interface.router_interface_a_1.name
}

# ============================================================
# BGP — Router interfaces and peers for Project B
# Mirror configuration of Project A with reversed IP addresses
# ============================================================

resource "google_compute_router_interface" "router_interface_b_0" {
  provider   = google.project_b
  name       = "bgp-interface-b-0"
  router     = google_compute_router.router_b.name
  region     = var.region
  ip_range   = "169.254.0.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_b_to_a_0.name
}

resource "google_compute_router_peer" "bgp_peer_b_0" {
  provider        = google.project_b
  name            = "bgp-peer-b-0"
  router          = google_compute_router.router_b.name
  region          = var.region
  peer_ip_address = "169.254.0.1"
  peer_asn        = var.asn_project_a
  interface       = google_compute_router_interface.router_interface_b_0.name
}

resource "google_compute_router_interface" "router_interface_b_1" {
  provider   = google.project_b
  name       = "bgp-interface-b-1"
  router     = google_compute_router.router_b.name
  region     = var.region
  ip_range   = "169.254.1.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_b_to_a_1.name
}

resource "google_compute_router_peer" "bgp_peer_b_1" {
  provider        = google.project_b
  name            = "bgp-peer-b-1"
  router          = google_compute_router.router_b.name
  region          = var.region
  peer_ip_address = "169.254.1.1"
  peer_asn        = var.asn_project_a
  interface       = google_compute_router_interface.router_interface_b_1.name
}

# ============================================================
# OUTPUTS
# Expose key resource attributes for verification and
# cross-referencing after terraform apply
# ============================================================

output "vm_a_internal_ip" {
  value       = google_compute_instance.vm_a.network_interface[0].network_ip
  description = "Internal IP of VM in Project A"
}

output "vm_b_internal_ip" {
  value       = google_compute_instance.vm_b.network_interface[0].network_ip
  description = "Internal IP of VM in Project B"
}

output "ha_vpn_gateway_a_ip_0" {
  value       = google_compute_ha_vpn_gateway.ha_vpn_gw_a.vpn_interfaces[0].ip_address
  description = "Public IP of HA VPN Gateway A — interface 0"
}

output "ha_vpn_gateway_a_ip_1" {
  value       = google_compute_ha_vpn_gateway.ha_vpn_gw_a.vpn_interfaces[1].ip_address
  description = "Public IP of HA VPN Gateway A — interface 1"
}

output "ha_vpn_gateway_b_ip_0" {
  value       = google_compute_ha_vpn_gateway.ha_vpn_gw_b.vpn_interfaces[0].ip_address
  description = "Public IP of HA VPN Gateway B — interface 0"
}

output "ha_vpn_gateway_b_ip_1" {
  value       = google_compute_ha_vpn_gateway.ha_vpn_gw_b.vpn_interfaces[1].ip_address
  description = "Public IP of HA VPN Gateway B — interface 1"
}
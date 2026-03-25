# Project A: your existing GCP project
variable "project_a_id" {
  description = "GCP Project A ID — the source/hub project"
  default     = "YOUR_PROJECT_A_ID"
}

# Project B: second GCP project simulating a remote network segment
variable "project_b_id" {
  description = "GCP Project B ID — the remote/spoke project"
  default     = "YOUR_PROJECT_B_ID"
}

variable "region" {
  description = "GCP region for all resources"
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for VM instances"
  default     = "us-central1-a"
}

# BGP ASNs must be unique on each side of the VPN tunnel.
# Using private ASN range 64512–65534 (RFC 6996).
variable "asn_project_a" {
  description = "BGP ASN for Cloud Router in Project A"
  default     = 64512
}

variable "asn_project_b" {
  description = "BGP ASN for Cloud Router in Project B"
  default     = 64513
}
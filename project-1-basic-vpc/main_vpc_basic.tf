# Provider configuration
# Note: replace project ID with your own GCP project ID before use
provider "google" {
  project = "YOUR_GCP_PROJECT_ID"
  region  = "us-central1"
}

# Custom-mode VPC network
# auto_create_subnetworks = false disables the default auto-mode behaviour,
# giving full control over subnet IP ranges and regions
resource "google_compute_network" "custom_vpc" {
  name                    = "my-custom-vpc"
  auto_create_subnetworks = false
}

# Three subnets in non-overlapping CIDR ranges within the same region
resource "google_compute_subnetwork" "subnet_1" {
  name          = "my-subnet-1"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.custom_vpc.id
}

resource "google_compute_subnetwork" "subnet_2" {
  name          = "my-subnet-2"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.custom_vpc.id
}

resource "google_compute_subnetwork" "subnet_3" {
  name          = "my-subnet-3"
  ip_cidr_range = "10.0.3.0/24"
  region        = "us-central1"
  network       = google_compute_network.custom_vpc.id
}

# Firewall rule allowing ICMP (ping) and SSH (TCP/22) from any source
# Scope: applies to all instances in the VPC
# Note: source_ranges = ["0.0.0.0/0"] is suitable for lab/testing environments only.
# In production, restrict to specific trusted IP ranges.
resource "google_compute_firewall" "allow_ssh_icmp" {
  name    = "allow-ssh-icmp-custom-vpc"
  network = google_compute_network.custom_vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Three VM instances — one per subnet, spread across availability zones
# e2-micro is the smallest general-purpose machine type, suitable for testing
# Each instance receives an ephemeral external IP via the empty access_config block

resource "google_compute_instance" "vm_1" {
  name         = "vm-in-subnet-1"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.subnet_1.id

    access_config {
      # Empty block assigns an ephemeral external (public) IP to the instance
    }
  }
}

resource "google_compute_instance" "vm_2" {
  name         = "vm-in-subnet-2"
  machine_type = "e2-micro"
  zone         = "us-central1-f" # Different zone from vm_1 for availability

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.subnet_2.id

    access_config {}
  }
}

resource "google_compute_instance" "vm_3" {
  name         = "vm-in-subnet-3"
  machine_type = "e2-micro"
  zone         = "us-central1-c"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.subnet_3.id

    access_config {}
  }
}
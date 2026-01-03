variable "project_id" {}
variable "region" {}

# 1. VPC Network B
resource "google_compute_network" "vpc_b" {
  name                    = "vpc-b"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# 2. GKE Subnet
resource "google_compute_subnetwork" "subnet_gke" {
  name          = "subnet-gke"
  region        = var.region
  network       = google_compute_network.vpc_b.id
  ip_cidr_range = "10.0.1.0/24"
  project       = var.project_id
}

# 3. PSC NAT Subnet
resource "google_compute_subnetwork" "psc_nat_subnet" {
  name          = "psc-nat-subnet"
  region        = var.region
  network       = google_compute_network.vpc_b.id
  ip_cidr_range = "10.0.2.0/24"
  purpose       = "PRIVATE_SERVICE_CONNECT"
  project       = var.project_id
}

# 4. GKE Autopilot Cluster
resource "google_container_cluster" "producer_cluster" {
  name     = "producer-cluster"
  location = var.region
  project  = var.project_id
  
  enable_autopilot = true

  network    = google_compute_network.vpc_b.name
  subnetwork = google_compute_subnetwork.subnet_gke.name
  
  ip_allocation_policy {}
  deletion_protection = false
}

# 5. Firewall Rule (Allow PSC Ingress)
resource "google_compute_firewall" "allow_psc_ingress" {
  name    = "allow-psc-ingress"
  network = google_compute_network.vpc_b.name
  project = var.project_id

  allow {
    protocol = "all"
  }
  direction = "INGRESS"
  source_ranges = ["10.0.2.0/24"] # PSC subnet range
}
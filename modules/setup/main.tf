variable "consumer_project_id" {}
variable "producer_project_id" {}

locals {
  services = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "dns.googleapis.com"
  ]
}

# Consumer API enablement
resource "google_project_service" "consumer_apis" {
  provider           = google.consumer
  for_each           = toset(local.services)
  project            = var.consumer_project_id
  service            = each.key
  disable_on_destroy = false
}

# Producer API enablement
resource "google_project_service" "producer_apis" {
  provider           = google.producer
  for_each           = toset(local.services)
  project            = var.producer_project_id
  service            = each.key
  disable_on_destroy = false
}

# API activation wait
resource "time_sleep" "wait_for_apis" {
  create_duration = "60s"
  depends_on = [
    google_project_service.consumer_apis,
    google_project_service.producer_apis
  ]
}
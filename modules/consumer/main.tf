# 1. VPC A
resource "google_compute_network" "vpc_a" {
  name                    = "vpc-a"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "subnet_consumer" {
  name          = "subnet-consumer"
  region        = var.region
  network       = google_compute_network.vpc_a.id
  ip_cidr_range = "10.10.1.0/24"
  project       = var.project_id
}

# 2. External IP
resource "google_compute_global_address" "external_lb_ip" {
  name    = "external-lb-ip"
  project = var.project_id
}

# 3. Wait for ServiceAttachment to be ready
resource "time_sleep" "wait_for_service_attachment" {
  create_duration = "300s"
}

# 4. PSC NEG
resource "google_compute_region_network_endpoint_group" "psc_neg" {
  name                  = "psc-neg-group"
  project               = var.project_id
  region                = var.region
  network               = google_compute_network.vpc_a.id
  subnetwork            = google_compute_subnetwork.subnet_consumer.id
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = var.producer_service_attachment_uri
  
  depends_on = [time_sleep.wait_for_service_attachment]
}

# 5. Cloud Armor
resource "google_compute_security_policy" "block_bad_guys" {
  name    = "block-bad-guys"
  project = var.project_id

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    description = "default rule"
  }
}

# 6. External Load Balancer (HTTP)
resource "google_compute_backend_service" "my_backend_service" {
  name                  = "my-backend-service"
  project               = var.project_id
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_security_policy.block_bad_guys.id
  
  backend {
    group          = google_compute_region_network_endpoint_group.psc_neg.id
    balancing_mode = "UTILIZATION"
  }
}

resource "google_compute_url_map" "my_url_map" {
  name            = "my-external-lb"
  project         = var.project_id
  default_service = google_compute_backend_service.my_backend_service.id
}

resource "google_compute_target_http_proxy" "my_http_proxy" {
  name    = "my-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.my_url_map.id
}

resource "google_compute_global_forwarding_rule" "my_forwarding_rule" {
  name                  = "my-forwarding-rule"
  project               = var.project_id
  target                = google_compute_target_http_proxy.my_http_proxy.id
  ip_address            = google_compute_global_address.external_lb_ip.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
output "external_lb_ip" {
  value = google_compute_global_address.external_lb_ip.address
}
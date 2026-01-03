// Convenience output that exposes the external HTTP load balancer URL
output "application_url" {
  description = "Access the application via this URL (HTTP)"
  value       = "http://${module.consumer.external_lb_ip}"
}
output "cluster_endpoint" { value = google_container_cluster.producer_cluster.endpoint }
output "cluster_ca_certificate" { value = google_container_cluster.producer_cluster.master_auth[0].cluster_ca_certificate }
output "psc_subnet_name" { value = google_compute_subnetwork.psc_nat_subnet.name }
output "psc_subnet_url" { value = google_compute_subnetwork.psc_nat_subnet.self_link }
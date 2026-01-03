output "service_attachment_uri" {
  value = "projects/${var.project_id}/regions/${var.region}/serviceAttachments/${local.service_attachment_name}"
}
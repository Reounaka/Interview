output "service_attachment_uri" {
  value = kubernetes_manifest.psc_attachment.object.status.serviceAttachmentURL
}
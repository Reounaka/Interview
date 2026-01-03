output "service_attachment_uri" {
  value = data.external.service_attachment_url.result.url
  depends_on = [data.external.service_attachment_url]
}
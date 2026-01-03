# --- Providers Internal Config ---
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "kubectl" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  load_config_file       = false
}

# 1. Deployment
resource "kubernetes_deployment_v1" "hello_server" {
  metadata { name = "hello-server" }
  spec {
    replicas = 2
    selector { match_labels = { app = "hello-server" } }
    template {
      metadata { labels = { app = "hello-server" } }
      spec {
        container {
          image = "us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0"
          name  = "hello-server"
          port { container_port = 8080 }
        }
      }
    }
  }
}

# 2. Internal Load Balancer
resource "kubernetes_service_v1" "internal_lb" {
  metadata {
    name = "internal-lb-service"
    annotations = {
      "networking.gke.io/load-balancer-type" = "Internal"
      "networking.gke.io/internal-load-balancer-allow-global-access" = "true"
    }
  }
  spec {
    selector = { app = "hello-server" }
    type     = "LoadBalancer"
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
  }
  depends_on = [kubernetes_deployment_v1.hello_server]
}

# 2.5. Wait for LB to get IP
resource "time_sleep" "wait_for_lb_ip" {
  create_duration = "30s"
  depends_on      = [kubernetes_service_v1.internal_lb]
}

# 3. Service Attachment (Using Kubectl for stability)
resource "kubectl_manifest" "psc_attachment" {
  yaml_body = yamlencode({
    apiVersion = "networking.gke.io/v1"
    kind       = "ServiceAttachment"
    metadata = {
      name      = "my-psc-service"
      namespace = "default"
    }
    spec = {
      connectionPreference = "ACCEPT_AUTOMATIC"
      natSubnets = [var.psc_subnet_url]
      resourceRef = {
        kind = "Service"
        name = kubernetes_service_v1.internal_lb.metadata[0].name
      }
    }
  })
  depends_on = [time_sleep.wait_for_lb_ip]
}

# 4. Wait for Propagation (300s)
resource "time_sleep" "wait_for_psc" {
  create_duration = "300s"
  depends_on      = [kubectl_manifest.psc_attachment]
}

# 5. Get Service Attachment URL
data "external" "service_attachment_url" {
  program = [
    "bash",
    "-c",
    <<-EOT
      set -euo pipefail
      # Poll until the service attachment exposes its URL, then emit a JSON map for Terraform's external data source
      # Allow up to ~10 minutes for the attachment to publish its URL, exit early when ready.
      for i in $(seq 1 60); do
        url=$(kubectl get serviceattachment my-psc-service -n default -o jsonpath='{.status.serviceAttachmentURL}' --request-timeout=10s 2>/dev/null || true)
        if [ -n "$url" ]; then
          break
        fi
        sleep 10
      done
      if [ -z "$url" ]; then
        echo "{}" >&2
        exit 1
      fi
      jq -n --arg url "$url" '{url: $url}'
    EOT
  ]
  depends_on = [time_sleep.wait_for_psc]
}
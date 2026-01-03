# Providers and defaults
data "google_client_config" "default" {}

locals {
  service_attachment_name = "my-psc-service"
}

provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

# App deployment (hello server)
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

# Internal Load Balancer Service (ILB)
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

# Wait for ILB IP before creating the attachment
resource "time_sleep" "wait_for_lb_ip" {
  create_duration = "30s"
  depends_on      = [kubernetes_service_v1.internal_lb]
}

# PSC ServiceAttachment CRD
resource "kubernetes_manifest" "psc_attachment" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ServiceAttachment"
    metadata = {
      name      = local.service_attachment_name
      namespace = "default"
    }
    spec = {
      connectionPreference = "ACCEPT_AUTOMATIC"
      natSubnets           = [var.psc_subnet_url]
      resourceRef = {
        kind = "Service"
        name = kubernetes_service_v1.internal_lb.metadata[0].name
      }
    }
  }
  depends_on = [time_sleep.wait_for_lb_ip]
}

# Fetch ServiceAttachment selfLink via gcloud command
data "external" "service_attachment_url" {
  program = [
    "bash",
    "-c",
    <<-EOT
      set -euo pipefail
      target="/namespaces/default/serviceattachments/${local.service_attachment_name}"
      for i in $(seq 1 60); do
        url=$(gcloud compute service-attachments list \
          --project "${var.project_id}" \
          --regions "${var.region}" \
          --format="value(selfLink,description)" \
          | awk -F"\t" -v t="$target" 'index($2,t){print $1; exit}')
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
  depends_on = [kubernetes_manifest.psc_attachment]
}

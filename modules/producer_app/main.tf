// Name of the ServiceAttachment created on the producer GKE cluster
locals {
  service_attachment_name = "my-psc-service"
}

# Deploy the hello application, internal LoadBalancer Service and PSC ServiceAttachment
# using gcloud + kubectl. This avoids configuring the Kubernetes provider against
# a cluster that is being created in the same apply, so a single terraform apply
# can provision the whole demo.
resource "null_resource" "deploy_psc_app" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      # Get kubeconfig credentials for the Autopilot GKE cluster
      gcloud container clusters get-credentials "producer-cluster" \
        --region "${var.region}" \
        --project "${var.project_id}"

      # Deploy a simple hello HTTP application and expose it internally
      cat <<'EOF' | kubectl apply -f -
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: hello-server
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: hello-server
        template:
          metadata:
            labels:
              app: hello-server
          spec:
            containers:
            - name: hello-server
              image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
              ports:
              - containerPort: 8080
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: internal-lb-service
        annotations:
          networking.gke.io/load-balancer-type: "Internal"
          networking.gke.io/internal-load-balancer-allow-global-access: "true"
      spec:
        type: LoadBalancer
        selector:
          app: hello-server
        ports:
        - port: 80
          targetPort: 8080
          protocol: TCP
      EOF

      # Wait for the internal GKE LoadBalancer Service to receive an IP
      sleep 60

      # Create the ServiceAttachment CRD pointing at the internal LB Service
      cat <<EOF | kubectl apply -f -
      apiVersion: networking.gke.io/v1
      kind: ServiceAttachment
      metadata:
        name: ${local.service_attachment_name}
        namespace: default
      spec:
        connectionPreference: ACCEPT_AUTOMATIC
        natSubnets:
        - ${var.psc_subnet_url}
        resourceRef:
          kind: Service
          name: internal-lb-service
      EOF
    EOT
  }
}

# Fetch the ServiceAttachment selfLink from GCP using gcloud
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
  depends_on = [null_resource.deploy_psc_app]
}

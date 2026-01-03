
# Terraform PSC Demo (GCP)

This project wires two GCP projects together via Private Service Connect (PSC):
- Producer (Project B): GKE Autopilot runs a hello HTTP app, exposed with a PSC ServiceAttachment.
- Consumer (Project A): An external HTTP load balancer reaches the producer through a PSC NEG.

## What gets created
- Producer: VPC B, GKE subnet, PSC NAT subnet, Autopilot cluster, firewall to allow PSC, internal Service + ServiceAttachment.
- Consumer: VPC A, subnet, PSC NEG targeting the ServiceAttachment, Cloud Armor policy, reserved global IP, external HTTP LB.
- Outputs: `application_url` = http://<consumer LB IP>.

## Layout
- Root: provider wiring, module calls, outputs.
- modules/setup: enables required Google APIs and waits.
- modules/producer_infra: network + Autopilot cluster + PSC NAT subnet + firewall.
- modules/producer_app: deploys the app, internal LB, PSC ServiceAttachment (Terraform-only, no kubectl).
- modules/consumer: PSC NEG, Cloud Armor, external HTTP LB.

## How to run
1) Set `terraform.tfvars`:
```
consumer_project_id = "<consumer-project>"
producer_project_id = "<producer-project>"
region              = "us-central1"
```
2) Apply:
```
terraform init
terraform apply -auto-approve
```
3) Grab the output `application_url` and open it in a browser.

## Prerequisites
- Terraform >= 1.3
- gcloud CLI authenticated to both projects
- Network/API access to the producer cluster for the Terraform Kubernetes provider
- Two GCP projects with billing enabled

## Destroy
```
terraform destroy -auto-approve
```
If you see errors about PSC attachments/subnets, wait a bit and rerun destroy after the ServiceAttachment and PSC NEG release.

## Troubleshooting
- ServiceAttachment publishing can take a few minutes; the consumer NEG depends on it being ready.
- Ensure the Terraform Kubernetes provider can reach the producer cluster API (credentials from gcloud must have cluster access).



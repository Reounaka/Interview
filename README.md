
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
- modules/producer_app: deploys the app, internal LB, PSC ServiceAttachment using a Terraform null_resource with gcloud + kubectl.
- modules/consumer: PSC NEG, Cloud Armor, external HTTP LB.

## How to run
1) Clone and enter the repo:
```
git clone https://github.com/Reounaka/Interview.git
cd Interview
```
2) Set `terraform.tfvars` in the repo root:
```
consumer_project_id = "<CONSUMER_PROJECT_ID>"  # consumer project (A)
producer_project_id = "<PRODUCER_PROJECT_ID>"  # producer project (B)
region              = "us-central1"
```
3) Authenticate with gcloud (same account must have access to both projects):
```
gcloud auth login
gcloud config set project <PRODUCER_PROJECT_ID>
```
4) Apply:
```
terraform init
terraform apply
```
5) Grab the output `application_url` and open it in a browser or curl it.

## Prerequisites
- Terraform >= 1.3
- gcloud CLI
- kubectl
- Two GCP projects with billing enabled

## Destroy
```
terraform destroy -auto-approve
```
If you see errors about PSC attachments/subnets, wait a bit and rerun destroy after the ServiceAttachment and PSC NEG release.

## Troubleshooting / notes
- ServiceAttachment publishing can take a few minutes; the consumer NEG depends on it being ready.
- The Kubernetes resources (Deployment, Service, ServiceAttachment) are created via `kubectl apply` from Terraform and are not tracked as Terraform resources.



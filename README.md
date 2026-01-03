
# Terraform PSC Demo (GCP)

Two GCP projects connected via Private Service Connect (PSC):
- Producer (Project B): GKE Autopilot runs a hello HTTP app, exposed through a ServiceAttachment.
- Consumer (Project A): External HTTP LB reaches the producer via a PSC NEG.

## What gets created
- Producer: VPC B, GKE subnet, PSC NAT subnet, Autopilot cluster, firewall for PSC, internal Service + ServiceAttachment.
- Consumer: VPC A, subnet, PSC NEG to the attachment, Cloud Armor policy, reserved global IP, external HTTP LB.
- Output: `application_url` (http://<consumer LB IP>).

## Repo map
- Root: provider wiring, module calls, outputs.
- modules/setup: enable required Google APIs and wait.
- modules/producer_infra: VPC B, subnets, Autopilot cluster, firewall.
- modules/producer_app: deploy app, internal LB, PSC ServiceAttachment, poll for URL.
- modules/consumer: VPC A, PSC NEG, Cloud Armor, external HTTP LB.

## Apply flow
1. setup → enable APIs and pause.
2. producer_infra → network + Autopilot cluster.
3. producer_app → app + internal LB + ServiceAttachment.
4. consumer → PSC NEG + Cloud Armor + external HTTP LB.

## Prerequisites
- Terraform >= 1.3
- gcloud CLI authenticated to both projects
- kubectl with access to the producer cluster API
- Two GCP projects with billing enabled

## Configure
Set `terraform.tfvars`:
```
consumer_project_id = "<consumer-project>"
producer_project_id = "<producer-project>"
region              = "us-central1"
```

## Run
```sh
terraform init
terraform apply -auto-approve
```
Outputs:
- `application_url`: http://<consumer LB IP>

## Destroy
```sh
terraform destroy -auto-approve
```
If destroy complains about PSC attachments/subnets, wait a minute and rerun after the ServiceAttachment and PSC NEG are gone.

## Troubleshooting
- ServiceAttachment URL can take a few minutes; the module polls until available.
- Ensure kubectl can reach the producer cluster before apply (`gcloud container clusters get-credentials ...` then `kubectl get ns --request-timeout=5s`).



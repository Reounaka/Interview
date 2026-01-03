terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  alias   = "consumer"
  project = var.consumer_project_id
  region  = var.region
}

provider "google" {
  alias   = "producer"
  project = var.producer_project_id
  region  = var.region
}

# STEP 0: enable required APIs in both projects
module "setup" {
  source = "./modules/setup"
  providers = {
    google.consumer = google.consumer
    google.producer = google.producer
  }
  consumer_project_id = var.consumer_project_id
  producer_project_id = var.producer_project_id
}

# STEP 1: create producer networking, subnets and GKE Autopilot cluster
module "producer_infra" {
  source = "./modules/producer_infra"
  providers = {
    google = google.producer
  }
  project_id = var.producer_project_id
  region     = var.region
  
  depends_on = [module.setup]
}

# STEP 2: deploy the producer application and PSC ServiceAttachment
module "producer_app" {
  source = "./modules/producer_app"

  cluster_endpoint       = module.producer_infra.cluster_endpoint
  cluster_ca_certificate = module.producer_infra.cluster_ca_certificate
  psc_subnet_name        = module.producer_infra.psc_subnet_name
  psc_subnet_url         = module.producer_infra.psc_subnet_url
  
  project_id      = var.producer_project_id
  region          = var.region

  providers = {
    google = google.producer
  }

  # Ensure the GKE cluster and related infra are fully created
  # before running the null_resource that uses gcloud/kubectl.
  depends_on = [module.producer_infra]
}

# STEP 3: create consumer networking, PSC NEG and external HTTP load balancer
module "consumer" {
  source = "./modules/consumer"
  providers = {
    google = google.consumer
  }
  project_id = var.consumer_project_id
  region     = var.region
  
  producer_service_attachment_uri = module.producer_app.service_attachment_uri
  depends_on = [module.producer_app]
}

output "load_balancer_ip" {
  value = module.consumer.external_lb_ip
}
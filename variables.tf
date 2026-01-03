// IDs of the consumer (A) and producer (B) GCP projects
variable "consumer_project_id" { type = string }
variable "producer_project_id" { type = string }

// Default region used for all regional resources
variable "region" { 
  type    = string
  default = "us-central1"
}
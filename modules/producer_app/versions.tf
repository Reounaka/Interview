terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    kubectl    = { source = "gavinbunney/kubectl" }
    google     = { source = "hashicorp/google" }
    time       = { source = "hashicorp/time" }
  }
}
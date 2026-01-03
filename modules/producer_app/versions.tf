terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    google     = { source = "hashicorp/google" }
    time       = { source = "hashicorp/time" }
  }
}
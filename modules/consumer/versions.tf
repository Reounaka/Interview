terraform {
  # Consumer module only requires the Google provider
  required_providers {
    google = { source = "hashicorp/google" }
  }
}
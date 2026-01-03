terraform {
  # This module only needs the Google provider
  required_providers {
    google = { source = "hashicorp/google" }
  }
}
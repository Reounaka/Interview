terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      configuration_aliases = [ google.consumer, google.producer ]
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
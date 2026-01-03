terraform {
  # Setup module uses the Google provider with two aliases (consumer, producer)
  # and the time provider to wait for API activation.
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
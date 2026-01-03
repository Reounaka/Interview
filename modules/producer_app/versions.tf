terraform {
  # This module uses the Google provider plus helper providers for
  # running local commands and external scripts
  required_providers {
    google   = { source = "hashicorp/google" }
    external = { source = "hashicorp/external" }
    null     = { source = "hashicorp/null" }
  }
}
terraform {
  required_version = "~> 1.15.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.43.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1.0"
    }
  }
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.26.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

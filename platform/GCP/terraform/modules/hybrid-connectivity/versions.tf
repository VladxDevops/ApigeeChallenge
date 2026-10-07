terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.26.0, < 8.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

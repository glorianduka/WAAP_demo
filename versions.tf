terraform {
  required_version = ">= 0.13"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.53"
    }
    apigee = {
      source  = "scastria/apigee"
      version = "~> 0.1.0"
    }
  }
  provider_meta "google" {
    module_name = "blueprints/terraform/test/v0.0.1"
  }
}

##########################################################
### Configure the Apigee Provider
##########################################################
provider "apigee" {
  access_token = var.access_token
  organization = google_apigee_organization.apigee_org.id
}




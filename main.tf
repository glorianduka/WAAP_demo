##########################################################
### Create a Google Cloud Project for the demo
##########################################################
# resource "google_folder" "terraform_demo" {
#   display_name = var.demo_folder_name
#   parent = "organizations/${var.org_id}"
# }

# resource "google_project" "waap_project" {
#   auto_create_network = true
# #   billing_account     = var.billing_account
# #   folder_id           = google_folder.terraform_demo.display_name
#   name                = var.project_name
#   project_id          = var.project_id
# }

##########################################################
### Enable Google Cloud APIs
##########################################################
resource "google_project_service" "apigee_googleapis_com" {
  project = var.project_id
  service = "apigee.googleapis.com"
}

resource "google_project_service" "cloudbuild_googleapis_com" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  disable_dependent_services = true
}
 
resource "google_project_service" "compute_googleapis_com" {
  project = var.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "cloudresourcemanager_googleapis_com" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "servicenetworking_googleapis_com" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "cloudkms_googleapis_com" {
  project = var.project_id
  service = "cloudkms.googleapis.com"
}

resource "google_project_service" "containerregistry_googleapis_com" {
  project = var.project_id
  service = "containerregistry.googleapis.com"
  disable_dependent_services = true
}

##########################################################
### Create Default VPC Network
##########################################################
resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = "default"
  description             = "Default network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute_googleapis_com]

}

##########################################################
### Create Default VPC Subnetwork
##########################################################
resource "google_compute_subnetwork" "default_subnet" {
  project       = var.project_id
  name          = "default"
  ip_cidr_range = "10.132.0.0/20"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network.id
  private_ip_google_access = true
  depends_on = [
    google_compute_network.vpc_network,
    google_project_service.compute_googleapis_com
  ]
}
##########################################################
### Reserve the peering ip range for Apigee (/22 for eval)
##########################################################
resource "google_compute_global_address" "google_managed_apigee" {
  address_type  = "INTERNAL"
  description   = "Peering range for Google Apigee X Tenant"
  name          = "google-managed-apigee"
  network       = google_compute_network.vpc_network.id
  prefix_length = 22
  project       = var.project_id
  purpose       = "VPC_PEERING"
}

############################################################################
### Reserve the peering ip range for Apigee (/28 for eval) - troubleshooting 
############################################################################
resource "google_compute_global_address" "google_managed_apigee_support" {
  address_type  = "INTERNAL"
  description   = "Peering range for supporting Apigee services"
  name          = "google-managed-apigee-support"
  network       = google_compute_network.vpc_network.id
  prefix_length = 28
  project       = var.project_id
  purpose       = "VPC_PEERING"
}

##########################################################
### Create the peering service networking connection
##########################################################
resource "google_service_networking_connection" "apigee_vpc_connection" {
  provider                = google
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google_managed_apigee.name]
  depends_on              = [google_project_service.servicenetworking_googleapis_com]
}

##########################################################
### Reserve the external IP address
##########################################################
resource "google_compute_global_address" "lb_ipv4_vip_1" {
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  name         = "lb-ipv4-vip-1"
  project      = var.project_id
  depends_on = [
    google_project_service.compute_googleapis_com
  ]
#   locals {
#   apigee_hostname = "${replace(google_compute_global_address.lb_ipv4_vip_1.address, ".", "-")}.nip.io"
#   }

}

# resource "google_storage_bucket" "cloud_storage_bucket_name" {
#   name          = "apigee-demo-terraform-state" 
#   location      = "EU"
#   force_destroy = true
#   project       = var.project_i
#   uniform_bucket_level_access = true
# #   depends_on = [
# #     time_sleep.wait_X_seconds
# #   ]
# }
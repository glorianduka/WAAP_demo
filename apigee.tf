##########################################################
### Create the KMS resources
##########################################################
resource "google_kms_key_ring" "apigeering" {
  provider   = google
  location   = "europe-west1"
  name       = "apigee_ring"
  project    = var.project_id
  depends_on = [google_project_service.cloudkms_googleapis_com]

}
resource "google_kms_crypto_key" "apigeekey" {
  key_ring                   = google_kms_key_ring.apigeering.id
  name                       = "apigee_key"
  purpose                    = "ENCRYPT_DECRYPT"
  provider                   = google
  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
  lifecycle {
    # use when destroying TF
    # prevent_destroy = false
    prevent_destroy = true
  }

}

# resource "google_project_service_identity" "apigee_sa" {
#   provider = google-beta
#   project  = var.project_id
#   service  = google_project_service.apigee_googleapis_com.service
# }

# resource "google_kms_crypto_key_iam_binding" "apigee_sa_keyuser" {
#   provider      = google
#   crypto_key_id = google_kms_crypto_key.apigeekey.id
#   role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
#   members = [
#     "serviceAccount:${google_project_service_identity.apigee_sa.email}",
#   ]
# }


##########################################################
### Create the Apigee Organization
##########################################################
resource "google_apigee_organization" "apigee_org" {
  project_id                           = var.project_id
  analytics_region                     = "europe-west1"
  description                          = "Terraform-provisioned Apigee Org"
  authorized_network                   = google_compute_network.vpc_network.id
  runtime_database_encryption_key_name = google_kms_crypto_key.apigeekey.id
  depends_on = [
    google_service_networking_connection.apigee_vpc_connection,
    # google_kms_crypto_key_iam_binding.apigee_sa_keyuser,
  ]
}

##########################################################
### Create the Apigee Instance
##########################################################
resource "google_apigee_instance" "apigee_instance" {
  name          = "eval-instance"
  location      = "europe-west1"
  description   = "Terraform-provisioned Apigee Runtime Instance"
  org_id        = google_apigee_organization.apigee_org.id
  disk_encryption_key_name = google_kms_crypto_key.apigeekey.id
}

##########################################################
### Create the Apigee Environment
##########################################################
resource "google_apigee_environment" "apigee_env" {
  org_id = google_apigee_organization.apigee_org.id
  name   = "eval"
}

##########################################################
### Attach the Apigee Environment to the Instance
##########################################################
resource "google_apigee_instance_attachment" "env_to_instance_attachment" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.apigee_env.name
}

##########################################################
### Create the Apigee Environment Group
##########################################################
resource "google_apigee_envgroup" "apigee_envgroup" {
  org_id    = google_apigee_organization.apigee_org.id
  name      = "eval-group"
  hostnames = [local.apigee_hostname]
}

##########################################################
### Attach the Apigee Environment to the Environment Group
##########################################################
resource "google_apigee_envgroup_attachment" "env_to_envgroup_attachment" {
  envgroup_id = google_apigee_envgroup.apigee_envgroup.id
  environment = google_apigee_environment.apigee_env.name
}





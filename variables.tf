variable "project_id" {
  type        = string
  description = "project id required"
}
variable "project_name" {
 type        = string
 description = "project name in which demo deploy"
}
variable "project_number" {
 type        = string
 description = "project number in which demo deploy"
}
# variable "gcp_account_name" {
#  description = "user performing the demo"
# }
# variable "deployment_service_account_name" {
#  description = "Cloudbuild_Service_account having permission to deploy terraform resources"
# }
# variable "key_credential" {
#     description = "The key of the apigee app credential"

# }
# variable "secret_credential" {
#     description = "The secret of the apigee app credential"
# }
variable "org_id" {
 description = "Organization ID in which project created"
}
# variable "billing_account"{
#     description = "billing account"    
# }
# variable "demo_folder_name" {
#     description = "name of folder demo resides in"
# }

variable "access_token" {
    description = "Access token"
}
variable "image_tag" {
    description = "Juice shop container registry tag (example: gcr.io/$PROJECT_ID/waap-juice-shop)"
}
locals {
  juiceshop_hostname = "${replace(google_compute_global_address.juiceshop_lb_ip.address, ".", "-")}.nip.io"
}
locals {
  apigee_hostname = "${replace(google_compute_global_address.lb_ipv4_vip_1.address, ".", "-")}.nip.io"
 }
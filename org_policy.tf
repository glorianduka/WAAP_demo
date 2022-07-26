#############################################################################################################################################################
#ORGANIZATION POLICIES/CONSTRAINT REQUIRED FOR THE RESOURCES/PRODUCT WE ARE USING                                                                           #
#INSIDE OUR TERRAFORM SCRIPTS.                                                                                                                              #
#ALLOWS MANAGEMENT OF ORGANIZATION POLICIES FOR A GOOGLE CLOUD PROJECT                                                                                      #      
#BOOLEAN CONSTRAINT POLICY CAN BE USED TO EXPLICITLY ALLOW A PARTICULAR CONSTRAINT ON AN INDIVIDUAL PROJECT, REGARDLESS OF HIGHER LEVEL POLICIES            #
#LIST CONSTRAINT POLICY THAT CAN DEFINE SPECIFIC VALUES THAT ARE ALLOWED OR DENIED FOR THE GIVEN CONSTRAINT. IT CAN ALSO BE USED TO ALLOW OR DENY ALL VALUES#
#############################################################################################################################################################
resource "google_project_organization_policy" "requireShieldedVm" {
  project     = var.project_id
  constraint = "compute.requireShieldedVm"
  boolean_policy {
    enforced = false
  }
}
resource "google_project_organization_policy" "skipDefaultNetworkCreation" {
  project     = var.project_id
  constraint = "compute.skipDefaultNetworkCreation"
  boolean_policy {
    enforced = false
  }
}
resource "google_project_organization_policy" "vmExternalIpAccess" {
  project     = var.project_id
  constraint = "compute.vmExternalIpAccess"
  list_policy {
    allow {
      all = true
    }
  }
}


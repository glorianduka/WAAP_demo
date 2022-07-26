
##########################################################
### Reserve the external IP address - juiceshop
##########################################################
resource "google_compute_global_address" "juiceshop_lb_ip" {
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  name         = "juiceshop-lb-ip"
  project      = var.project_id
  depends_on = [
    google_project_service.compute_googleapis_com
  ]
#   locals {
#   juiceshop_hostname = "${replace(google_compute_global_address.juiceshop_lb_ip.address, ".", "-")}.nip.io"
#   }
}

##########################################################
### Import proxy bundle ???
##########################################################
# resource "apigee_proxy" "apigee_proxy_bundle" {
#   name = "waap-demo-proxy-bundle"
#   bundle = "proxies/waap-demo-proxy-bundle.zip"
#   bundle_hash = filebase64sha256("proxies/waap-demo-proxy-bundle.zip")
# }

# resource "apigee_proxy_deployment" "proxy_deployment" {
#   proxy_name = apigee_proxy.apigee_proxy_bundle.name
#   environment_name = "eval"
#   revision = apigee_proxy.apigee_proxy_bundle.revision
# }

##########################################################
### create target server
##########################################################
resource "apigee_target_server" "target_server" {
  environment_name = "eval"
  name = "waap-demo-ts"
  host = "${replace(google_compute_global_address.juiceshop_lb_ip.address, ".", "-")}.nip.io"
  port = 443
  ssl_enabled = true
}

##########################################################
### create API Product
##########################################################
# resource "apigee_product" "waap_api_product" {
#   name = "waap-product"
#   display_name = "waap-product"
#   auto_approval_type = true
#   description = "WAAP Product API"
#   environments = [
#     "eval"
#   ]
#   attributes = {
#     access = "public"
#   }
#   operation {
#     api_source = apigee_proxy.apigee_proxy_bundle.name
#     path       = "/"
#     methods    = [
#         "GET",
#         "POST"
#     ]
#   }
# }

##########################################################
### create developer
##########################################################
resource "apigee_developer" "waap_developer" {
  email = "developer@waap.com"
  first_name = "waap"
  last_name = "developer"
  user_name = "waap"
}
resource "apigee_developer_app" "waap_developer_app" {
  developer_email = apigee_developer.waap_developer.email
  name = "waap-app"
}

# resource "apigee_developer_app_credential" "devAppCredential" {
    
#   developer_email = apigee_developer.waap_developer.email
#   developer_app_name = apigee_developer_app.waap_developer_app.name
#   consumer_key = var.key_credential
#   consumer_secret = var.secret_credential
#   api_products = [
#     apigee_product.waap_api_product.name
#   ]
# }


##########################################################
### configure compute engine SA
##########################################################
resource "google_service_account" "compute_service_account" {
  account_id   = "compute-service-account"
  display_name = "Compute Engine default service account"
  project      = var.project_id
}


#build docker image########################################################################################################################################
# resource "google_artifact_registry_repository" "waap_apigee_repo" {
#   format        = "DOCKER"
#   location      = "europe-west1"
#   project       = var.project_id
#   repository_id = "waap-apigee-repo"
# }

# resource "google_cloudbuild_trigger" "build-trigger" {
#   trigger_template {
#     branch_name = "main"
#     repo_name   = "my-repo"
#   }

#   build {
#     step {
#       name = "gcr.io/cloud-builders/gsutil"
#       args = ["cp", "gs://mybucket/remotefile.zip", "localfile.zip"]
#       timeout = "120s"
#       secret_env = ["MY_SECRET"]
#     }

#     source {
#       storage_source {
#         bucket = "mybucket"
#         object = "source_code.tar.gz"
#       }
#     }
#     tags = ["build", "newFeature"]
#     substitutions = {
#       _FOO = "bar"
#       _BAZ = "qux"
#     }
#     queue_ttl = "20s"
#     logs_bucket = "gs://mybucket/logs"
#     secret {
#       kms_key_name = "projects/myProject/locations/global/keyRings/keyring-name/cryptoKeys/key-name"
#       secret_env = {
#         PASSWORD = "ZW5jcnlwdGVkLXBhc3N3b3JkCg=="
#       }
#     }
#     available_secrets {
#       secret_manager {
#         env          = "MY_SECRET"
#         version_name = "projects/myProject/secrets/mySecret/versions/latest"
#       }
#     }
#     artifacts {
#       images = ["gcr.io/$PROJECT_ID/$REPO_NAME:$COMMIT_SHA"]
#       objects {
#         location = "gs://bucket/path/to/somewhere/"
#         paths = ["path"]
#       }
#     }
#     options {
#       source_provenance_hash = ["MD5"]
#       requested_verify_option = "VERIFIED"
#       machine_type = "N1_HIGHCPU_8"
#       disk_size_gb = 100
#       substitution_option = "ALLOW_LOOSE"
#       dynamic_substitutions = true
#       log_streaming_option = "STREAM_OFF"
#       worker_pool = "pool"
#       logging = "LEGACY"
#       env = ["ekey = evalue"]
#       secret_env = ["secretenv = svalue"]
#       volumes {
#         name = "v1"
#         path = "v1"
#       }
#     }
#   }
# }


##########################################################
### configure firewall rules
##########################################################
resource "google_compute_firewall" "allow_all_egress_juiceshop_https" {
  allow {
    ports    = ["443"]
    protocol = "tcp"
  }

  destination_ranges = ["0.0.0.0/0"]
  direction          = "EGRESS"
  name               = "allow-all-egress-juiceshop-https"
  network            = google_compute_network.vpc_network.id
  priority           = 1000
  project            = var.project_id
  target_tags        = ["juiceshop"]
}


resource "google_compute_firewall" "allow_juiceshop_demo_lb_health_check" {
  allow {
    ports    = ["80", "443", "3000"]
    protocol = "tcp"
  }

  direction     = "INGRESS"
  name          = "allow-juiceshop-demo-lb-health-check"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  project       = var.project_id
  source_ranges = ["0.0.0.0/0", "130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["juiceshop"]
}
resource "google_compute_firewall" "default_allow_http" {
  allow {
    ports    = ["80"]
    protocol = "tcp"
  }

  direction     = "INGRESS"
  name          = "default-allow-http"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}
resource "google_compute_firewall" "default_allow_https" {
  allow {
    ports    = ["443"]
    protocol = "tcp"
  }

  direction     = "INGRESS"
  name          = "default-allow-https"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
}
resource "google_compute_firewall" "default_allow_http_3000" {
  allow {
    ports    = ["3000"]
    protocol = "tcp"
  }

  direction     = "INGRESS"
  name          = "default-allow-http-3000"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
}




resource "google_compute_firewall" "default_allow_custom" {
  allow {
    protocol = "all"
  }

  description   = "Allows connection from any source to any instance on the network using custom protocols."
  direction     = "INGRESS"
  name          = "default-allow-custom"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["10.128.0.0/9"]
}
resource "google_compute_firewall" "default_allow_icmp" {
  allow {
    protocol = "icmp"
  }

  description   = "Allows ICMP connections from any source to any instance on the network."
  direction     = "INGRESS"
  name          = "default-allow-icmp"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_firewall" "default_allow_ipv6_custom" {
  allow {
    protocol = "all"
  }

  description   = "Allows connection from any source to any instance on the network using custom protocols."
  direction     = "INGRESS"
  name          = "default-allow-ipv6-custom"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_firewall" "default_allow_ipv6_icmp" {
  allow {
    protocol = "58"
  }

  description   = "Allows ICMP connections from any source to any instance on the network."
  direction     = "INGRESS"
  name          = "default-allow-ipv6-icmp"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["::/0"]
}
resource "google_compute_firewall" "default_allow_ipv6_rdp" {
  allow {
    ports    = ["3389"]
    protocol = "tcp"
  }

  description   = "Allows RDP connections from any source to any instance on the network using port 3389."
  direction     = "INGRESS"
  name          = "default-allow-ipv6-rdp"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["::/0"]
}
resource "google_compute_firewall" "default_allow_ipv6_ssh" {
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }

  description   = "Allows TCP connections from any source to any instance on the network using port 22."
  direction     = "INGRESS"
  name          = "default-allow-ipv6-ssh"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["::/0"]
}
resource "google_compute_firewall" "default_allow_rdp" {
  allow {
    ports    = ["3389"]
    protocol = "tcp"
  }

  description   = "Allows RDP connections from any source to any instance on the network using port 3389."
  direction     = "INGRESS"
  name          = "default-allow-rdp"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_firewall" "default_allow_ssh" {
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }

  description   = "Allows TCP connections from any source to any instance on the network using port 22."
  direction     = "INGRESS"
  name          = "default-allow-ssh"
  network       = google_compute_network.vpc_network.id
  priority      = 65534
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
}

##########################################################
### Create MIG - Juiceshop
##########################################################

# Build gce container
module "gce-container" {
  source = "terraform-google-modules/container-vm/google"
  version = "~> 3.0"

  container = {
    name = "juiceshop-demo-mig-template"
    image= var.image_tag
    securityContext = {
      privileged : false
    }
    stdin : false
    tty : true

    # Declare volumes to be mounted.
    # This is similar to how docker volumes are declared.
    volumeMounts = []
  }

  # Declare the Volumes which will be used for mounting.
  volumes = []

  restart_policy = "Always"
}

# Create an instance template
resource "google_compute_instance_template" "juiceshop_demo_mig_template" {
  disk {
    auto_delete  = true
    boot         = true
    device_name  = "juiceshop-demo-template"
    disk_size_gb = 10
    disk_type    = "pd-balanced"
    mode         = "READ_WRITE"
    source_image = "https://compute.googleapis.com/compute/v1/projects/cos-cloud/global/images/cos-stable-89-16108-470-1"
    type         = "PERSISTENT"
  }

  labels = {
    container-vm = "cos-stable-89-16108-470-1"
  }

  machine_type = "n2-standard-2"

  metadata = {
    gce-container-declaration = module.gce-container.metadata_value
    google-logging-enabled    = "true"
  }

  name = "juiceshop-demo-mig-template"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    network            = google_compute_network.vpc_network.id
    subnetwork         = google_compute_subnetwork.default_subnet.id
    subnetwork_project = var.project_id
  }

  project = var.project_id
  region  = "europe-west1"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    # provisioning_model  = "STANDARD"
  }

  service_account {
    email  = google_service_account.compute_service_account.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_vtpm                 = true
  }

  tags = ["http-server", "https-server", "juiceshop"]
}

# Create a managed instance group
resource "google_compute_region_instance_group_manager" "mig_manager_juiceshop" {
  name               = "juiceshop-demo-mig"
  project            = var.project_id
  base_instance_name = "juiceshop-demo-mig"
  region             = "europe-west1"
  version {
    instance_template  = google_compute_instance_template.juiceshop_demo_mig_template.id
  }
  named_port {
    name = "http-juiceshop"
    port = 3000
  }
}

# Configure autoscaling for the group
resource "google_compute_region_autoscaler" "mig_autoscaler_juiceshop" {
  name    = "juiceshop-demo-mig-autoscaler"
  project = var.project_id
  region  = "europe-west1"
  target  = google_compute_region_instance_group_manager.mig_manager_juiceshop.id
  autoscaling_policy {
    max_replicas    = 2
    min_replicas    = 1
    cooldown_period = 60
    cpu_utilization {
      target = 0.60
    }
  }
}


##########################################################
### Create the SSL certificate
##########################################################
resource "google_compute_managed_ssl_certificate" "juiceshopcert" {
  project = var.project_id
  name    = "juiceshopcert"
  managed {
    domains = [local.juiceshop_hostname]
  }
}

##########################################################
### Create the L7 GCLB
##########################################################

# Create a health check
resource "google_compute_health_check" "juiceshop_healthcheck" {
  check_interval_sec = 10
  healthy_threshold  = 2

  http_health_check {
    port               = 3000
    port_specification = "USE_FIXED_PORT"
    proxy_header       = "NONE"
    request_path       = "/rest/admin/application-version"
  }

  name                = "juiceshop-healthcheck"
  project             = var.project_id
  timeout_sec         = 5
  unhealthy_threshold = 3
  depends_on = [
    google_project_service.compute_googleapis_com
  ]
}

# Create a backend service
resource "google_compute_backend_service" "juiceshop_be" {
  connection_draining_timeout_sec = 0
  health_checks                   = [google_compute_health_check.juiceshop_healthcheck.id]
  load_balancing_scheme           = "EXTERNAL"

  log_config {
    enable = true
  }

  name             = "juiceshop-be"
  port_name        = "http-juiceshop"
  project          = var.project_id
  protocol         = "HTTP"
  security_policy  = google_compute_security_policy.waap_policies.name
  session_affinity = "NONE"
  timeout_sec      = 30
}

# Create a Load Balancing URL map
resource "google_compute_url_map" "juiceshop_url_map" {
  default_service = google_compute_backend_service.juiceshop_be.id
  name            = "juiceshop-url-map"
  project         = var.project_id
}

# Create a Load Balancing target HTTPS proxy
resource "google_compute_target_https_proxy" "juiceshop_https_target" {
  name             = "juiceshop-https-target"
  project          = var.project_id
  quic_override    = "NONE"
  ssl_certificates = [google_compute_managed_ssl_certificate.juiceshopcert.id]
  url_map          = google_compute_url_map.juiceshop_url_map.id
}


# Create a global forwarding rule
resource "google_compute_global_forwarding_rule" "juiceshop_fwd_rule" {
  ip_address            = google_compute_global_address.juiceshop_lb_ip.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  name                  = "juiceshop-fwd-rule"
  port_range            = "443-443"
  project               = var.project_id
  target                = google_compute_target_https_proxy.juiceshop_https_target.id
}



##########################################################
### Configure security policies - Cloud Armor 
##########################################################

resource "google_compute_security_policy" "waap_policies" {
  name    = "waap-policies"
  project = var.project_id
  depends_on = [
    google_project_service.compute_googleapis_com
  ]
#   type = "CLOUD_ARMOR"
#   advanced_options_config{
#         


#   }


  rule {
    action      = "allow"
    description = "Default rule, higher priority overrides it"

    match {
      config {
        src_ip_ranges = ["*"]
      }

      versioned_expr = "SRC_IPS_V1"
    }

    priority = 2147483647
  }

  rule {
    action      = "allow"
    description = "Deny all requests below 0.8 recaptcha score"

    match {
      expr {
        expression = "recaptchaTokenScore() <= 0.9"
      }
    }

    priority = 10000
  }

  rule {
    action      = "deny(403)"
    description = "Block US IP & header: Hacker"

    match {
      expr {
        expression = "origin.region_code == 'US' && request.headers['user-agent'].contains('Hacker')"
      }
    }

    priority = 7000
  }

  rule {
    action      = "deny(403)"
    description = "Regular Expression Rule"

    match {
      expr {
        expression = "request.headers['user-agent'].contains('Hacker')"
      }
    }

    priority = 7001
  }

  rule {
    action      = "deny(403)"
    description = "block sql injection"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable', ['owasp-crs-v030001-id942251-sqli', 'owasp-crs-v030001-id942420-sqli', 'owasp-crs-v030001-id942431-sqli', 'owasp-crs-v030001-id942460-sqli', 'owasp-crs-v030001-id942421-sqli', 'owasp-crs-v030001-id942432-sqli'])"
      }
    }

    priority = 9000
  }

  rule {
    action      = "deny(403)"
    description = "block xss"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable', ['owasp-crs-v030001-id941110-xss', 'owasp-crs-v030001-id941120-xss', 'owasp-crs-v030001-id941130-xss', 'owasp-crs-v030001-id941140-xss', 'owasp-crs-v030001-id941160-xss', 'owasp-crs-v030001-id941170-xss', 'owasp-crs-v030001-id941180-xss', 'owasp-crs-v030001-id941190-xss', 'owasp-crs-v030001-id941200-xss', 'owasp-crs-v030001-id941210-xss', 'owasp-crs-v030001-id941220-xss', 'owasp-crs-v030001-id941230-xss', 'owasp-crs-v030001-id941240-xss', 'owasp-crs-v030001-id941250-xss', 'owasp-crs-v030001-id941260-xss', 'owasp-crs-v030001-id941270-xss', 'owasp-crs-v030001-id941280-xss', 'owasp-crs-v030001-id941290-xss', 'owasp-crs-v030001-id941300-xss', 'owasp-crs-v030001-id941310-xss', 'owasp-crs-v030001-id941350-xss', 'owasp-crs-v030001-id941150-xss', 'owasp-crs-v030001-id941320-xss', 'owasp-crs-v030001-id941330-xss', 'owasp-crs-v030001-id941340-xss'])"
      }
    }

    priority = 3000
  }

}
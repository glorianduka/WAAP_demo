##########################################################
### Create MIG Network 
##########################################################
# Create an instance template
resource "google_compute_instance_template" "apigee_proxy_europe_west1" {
  project = var.project_id
  machine_type = "e2-micro"
  region  = "europe-west1"
  name = "apigee-proxy-europe-west1"
  tags = ["apigee-network-proxy", "gke-apigee-proxy", "https-server"]
  disk {
    auto_delete  = true
    boot         = true
    device_name  = "persistent-disk-0"
    disk_size_gb = 20
    mode         = "READ_WRITE"
    source_image = "projects/centos-cloud/global/images/family/centos-7"
    type         = "PERSISTENT"
  }
  network_interface {
    network            = google_compute_network.vpc_network.id
    subnetwork         = google_compute_subnetwork.default_subnet.id
  }
  metadata = {
    ENDPOINT           = google_apigee_instance.apigee_instance.host
    startup-script-url = "gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script.sh"
  }
  service_account {
    email  = google_service_account.compute_service_account.email
    scopes = ["storage-ro", "logging-write", "monitoring-write", "pubsub", "service-management", "service-control", "trace"]
  }
    
  labels = {
    managed-by-cnrm = "true"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    # provisioning_model  = "STANDARD"
  }
}


# Create a managed instance group
resource "google_compute_region_instance_group_manager" "mig_manager" {
  name               = "apigee-proxy-europe-west1"
  project            = var.project_id
  base_instance_name = "apigee-proxy"
  region             = "europe-west1"
  version {
    instance_template  = google_compute_instance_template.apigee_proxy_europe_west1.id
  }
  named_port {
    name = "https"
    port = 443
  }
}

# Configure autoscaling for the group
resource "google_compute_region_autoscaler" "mig_autoscaler" {
  name    = "apigee-proxy-europe-west1-xyog"
  project = var.project_id
  region  = "europe-west1"
  target  = google_compute_region_instance_group_manager.mig_manager.id
  autoscaling_policy {
    max_replicas    = 20
    min_replicas    = 2
    cooldown_period = 90
    cpu_utilization {
      target = 0.75
    }
  }
}

##########################################################
### Configure the firewall between the GCLB and MIG 
##########################################################
resource "google_compute_firewall" "k8s_allow_lb_to_apigee_proxy" {
  allow {
    ports    = ["443"]
    protocol = "tcp"
  }

  description   = "Allow incoming from GLB on TCP port 443 to Apigee Proxy"
  direction     = "INGRESS"
  name          = "k8s-allow-lb-to-apigee-proxy"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  project       = var.project_id
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["gke-apigee-proxy"]
}

##########################################################
### Create the SSL certificate
##########################################################
resource "google_compute_managed_ssl_certificate" "apigee_ssl_cert" {
  project = var.project_id
  name    = "apigee-ssl-cert"
  managed {
    domains = [local.apigee_hostname]
  }
}

##########################################################
### Create the L7 GCLB
##########################################################

# Create a health check
resource "google_compute_health_check" "hc_apigee_proxy_443" {
  check_interval_sec = 5
  healthy_threshold  = 2

  https_health_check {
    port               = 443
    port_specification = "USE_FIXED_PORT"
    proxy_header       = "NONE"
    request_path       = "/healthz/ingress"
  }

  name                = "hc-apigee-proxy-443"
  project             = var.project_id
  timeout_sec         = 5
  unhealthy_threshold = 2
  depends_on = [
    google_project_service.compute_googleapis_com
  ]
}


# Create a backend service
resource "google_compute_backend_service" "apigee_proxy_backend" {
  connection_draining_timeout_sec = 300
  health_checks                   = [google_compute_health_check.hc_apigee_proxy_443.id]
  load_balancing_scheme           = "EXTERNAL"
  name                            = "apigee-proxy-backend"
  port_name                       = "https"
  project                         = var.project_id
  protocol                        = "HTTPS"
  security_policy                 = google_compute_security_policy.waap_policies.name
  session_affinity                = "NONE"
  timeout_sec                     = 60
  backend {
    group = google_compute_region_instance_group_manager.mig_manager.instance_group
  }
}

# Create a Load Balancing URL map
resource "google_compute_url_map" "apigee_proxy_map" {
  default_service = google_compute_backend_service.apigee_proxy_backend.id
  name            = "apigee-proxy-map"
  project         = var.project_id
}

# Create a Load Balancing target HTTPS proxy
resource "google_compute_target_https_proxy" "apigee_proxy_https_proxy" {
  name             = "apigee-proxy-https-proxy"
  project          = var.project_id
  quic_override    = "NONE"
  ssl_certificates = [google_compute_managed_ssl_certificate.apigee_ssl_cert.id]
  url_map          = google_compute_url_map.apigee_proxy_map.id
}

# Create a global forwarding rule
resource "google_compute_global_forwarding_rule" "apigee_proxy_https_lb_rule" {
  ip_address            = google_compute_global_address.lb_ipv4_vip_1.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  name                  = "apigee-proxy-https-lb-rule"
  port_range            = "443-443"
  project               = var.project_id
  target                = google_compute_target_https_proxy.apigee_proxy_https_proxy.id
}
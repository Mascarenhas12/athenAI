// Create Storage bucket for image tars
resource "google_storage_bucket" "image_bucket" {
 name          = "vm-images"
 location      = "EU"
 storage_class = "STANDARD"
 force_destroy = true

 uniform_bucket_level_access = true

   lifecycle_rule {
    condition {
      age = 3
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

//Upload Talos GCP linux tar
resource "google_storage_bucket_object" "talos_tar" {
 name         = "talos-linux-gcp-amd64"
 source       = "gcp-amd64.raw.tar.gz"
 bucket       = google_storage_bucket.image_bucket.id
}

//Register talos image in Compute Engine
resource "google_compute_image" "talos_image" {
  name = "talos-linux-amd64"

  raw_disk {
    source = "${google_storage_bucket.image_bucket.url}/${google_storage_bucket_object.talos_tar.name}"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }
}

// Create Instance group, ports and healthcheck
resource "google_compute_instance_group" "talos_vms" {
  name        = "talos-vms"
  description = "Talos linux instance group"

  named_port {
    name = "health"
    port = "6443"
  }

  zone = local.region
}

resource "google_compute_health_check" "talos-vms-health-check" {
  name = "tcp-health-check"

  timeout_sec        = 300 // 5 minutes

  tcp_health_check {
    port = "6443"
  }
}

// Create Backend
resource "google_compute_backend_service" "backend" {
  name          = "talos-backend-service"
  health_checks = [google_compute_health_check.talos-vms-health-check.id]
  backend {
    group = google_compute_instance_group.talos_vms.id
  }
}

// Create TCP proxy
resource "google_compute_target_tcp_proxy" "tcp_proxy" {
  name            = "talos-tcp-proxy"
  backend_service = google_compute_backend_service.backend.id
  proxy_header = "NONE"
}

// Create LB address
resource "google_compute_global_address" "talos_lb_ip" {
  name = "talos-lb"
}

// Create forwarding rule
resource "google_compute_global_forwarding_rule" "lb_public" {
  name                  = "tcp-proxy-xlb-forwarding-rule"
  provider              = google-beta
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_tcp_proxy.tcp_proxy.id
  ip_address            = google_compute_global_address.talos_lb_ip.id
}

// Create firewall rules
// FW Health checks
resource "google_compute_firewall" "fw_health_rule" {
  project     = local.project_name
  name        = "fw-health"
  network     = "default"

  allow {
    protocol  = "tcp"
    ports     = ["50000"]

  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["talos-controlplane"]
}

// FW Talosctl
resource "google_compute_firewall" "fw_talosctl_rule" {
  project     = local.project_name
  name        = "fw-talosctl"
  network     = "default"

  allow {
    protocol  = "tcp"
    ports     = ["6443"]

  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags = ["talos-controlplane"]
}


locals {
  name = "owntracks"
  tag  = "owntracks"

  # Google IAP TCP forwarding source range (SSH without a public SSH port)
  iap_range = "35.235.240.0/20"
}

# Custom network: no default allow-ssh/rdp/icmp rules
resource "google_compute_network" "this" {
  name                    = "${local.name}-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  name          = "${local.name}-subnet"
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_firewall" "mqtts" {
  name          = "allow-mqtts"
  network       = google_compute_network.this.name
  direction     = "INGRESS"
  source_ranges = var.mqtt_source_ranges
  target_tags   = [local.tag]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.mqtt_port)]
  }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "allow-iap-ssh"
  network       = google_compute_network.this.name
  direction     = "INGRESS"
  source_ranges = [local.iap_range]
  target_tags   = [local.tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Static IP on the Standard network tier. The server certificate is issued for this address.
resource "google_compute_address" "this" {
  name         = "${local.name}-ip"
  region       = var.region
  network_tier = "STANDARD"
}

resource "google_compute_instance" "this" {
  name         = local.name
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = [local.tag]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/${var.image_family}"
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.this.id

    access_config {
      nat_ip       = google_compute_address.this.address
      network_tier = "STANDARD"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "FALSE"
    ssh-keys               = "${var.ssh_user}:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
    block-project-ssh-keys = "TRUE"
    startup-script         = file("${path.module}/../server/startup.sh")
  }

  # No service_account block: the VM holds no Google API credentials.

  allow_stopping_for_update = true
}

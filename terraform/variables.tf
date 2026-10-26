variable "project_id" {
  description = "GCP project ID created by scripts/bootstrap.sh."
  type        = string
}

variable "region" {
  description = "Always Free e2-micro regions: us-west1, us-central1, us-east1."
  type        = string
  default     = "us-west1"

  validation {
    condition     = contains(["us-west1", "us-central1", "us-east1"], var.region)
    error_message = "Use an Always Free region (us-west1, us-central1, us-east1)."
  }
}

variable "zone" {
  description = "Zone inside var.region."
  type        = string
  default     = "us-west1-b"
}

variable "subnet_cidr" {
  description = "Private range for the VM subnet."
  type        = string
  default     = "10.10.0.0/24"
}

variable "mqtt_port" {
  description = "MQTT over TLS listener port."
  type        = number
  default     = 8883
}

variable "mqtt_source_ranges" {
  description = "Source ranges allowed to reach the MQTT port. Phones on cellular change IPs, so the default is any address; authentication and TLS protect the listener."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "image_family" {
  description = "Debian image family for the VM."
  type        = string
  default     = "debian-13"
}

variable "disk_size_gb" {
  description = "Boot disk size. Always Free covers 30 GB of standard persistent disk."
  type        = number
  default     = 10
}

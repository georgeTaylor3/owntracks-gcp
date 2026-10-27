output "server_ip" {
  description = "Static IP the phones connect to. Used as the certificate SAN."
  value       = google_compute_address.this.address
}

output "ssh_command" {
  description = "SSH through IAP."
  value       = "gcloud compute ssh ${var.ssh_user}@${google_compute_instance.this.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap"
}

output "project_id" {
  value = var.project_id
}

output "zone" {
  value = var.zone
}

output "instance_name" {
  value = google_compute_instance.this.name
}

output "ssh_user" {
  value = var.ssh_user
}

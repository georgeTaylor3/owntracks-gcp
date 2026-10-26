#!/usr/bin/env bash
# Push the Mosquitto config, ACL and TLS files to the VM over IAP and restart the broker.
#
# Usage: scripts/deploy-server.sh
# Reads project, zone and instance name from Terraform outputs.
set -euo pipefail
umask 077

root="$(cd "$(dirname "$0")/.." && pwd)"
tf="$root/terraform"
pki="$root/pki/out"

for f in ca.crt server.crt server.key; do
  [[ -f "$pki/$f" ]] || { echo "Missing $pki/$f. Run pki/make-certs.sh <server-ip> first."; exit 1; }
done

project=$(terraform -chdir="$tf" output -raw project_id)
zone=$(terraform -chdir="$tf" output -raw zone)
vm=$(terraform -chdir="$tf" output -raw instance_name)
ssh_args=(--project="$project" --zone="$zone" --tunnel-through-iap)

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp "$root/server/mosquitto.conf" "$stage/owntracks.conf"
cp "$root/server/acl" "$root/server/add-user.sh" "$stage/"
cp "$pki/ca.crt" "$pki/server.crt" "$pki/server.key" "$stage/"

# Stage in the OS Login user's home directory, not world-writable /tmp
gcloud compute ssh "$vm" "${ssh_args[@]}" --command='rm -rf ~/owntracks-deploy'
gcloud compute scp "${ssh_args[@]}" --recurse "$stage" "$vm:owntracks-deploy"

gcloud compute ssh "$vm" "${ssh_args[@]}" --command='
set -euo pipefail
d=~/owntracks-deploy
chmod 700 "$d"
sudo install -d -m 750 -o root -g mosquitto /etc/mosquitto/certs
sudo install -m 644 -o root -g root      "$d/ca.crt"         /etc/mosquitto/certs/ca.crt
sudo install -m 644 -o root -g root      "$d/server.crt"     /etc/mosquitto/certs/server.crt
sudo install -m 640 -o root -g mosquitto "$d/server.key"     /etc/mosquitto/certs/server.key
sudo install -m 644 -o root -g root      "$d/owntracks.conf" /etc/mosquitto/conf.d/owntracks.conf
sudo install -m 600 -o mosquitto -g mosquitto "$d/acl"       /etc/mosquitto/acl
sudo install -m 750 -o root -g root      "$d/add-user.sh"    /usr/local/sbin/owntracks-add-user
sudo touch /etc/mosquitto/passwd
sudo chown mosquitto:mosquitto /etc/mosquitto/passwd
sudo chmod 600 /etc/mosquitto/passwd
rm -rf "$d"
sudo systemctl enable mosquitto
sudo systemctl restart mosquitto
sudo systemctl --no-pager --lines=5 status mosquitto
'
echo
echo "Deployed. Add a user (repeat per person):"
echo "  gcloud compute ssh $vm ${ssh_args[*]} -- sudo owntracks-add-user <username>"

#!/usr/bin/env bash
# GCE startup script. Runs on every boot; each step is idempotent.
# Installs Mosquitto and automatic security updates. TLS material, the
# Mosquitto config, users and ACLs are pushed with scripts/deploy-server.sh.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if ! dpkg -s mosquitto >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends mosquitto unattended-upgrades
fi

# Automatic security updates, reboot at 04:00 UTC when a kernel update needs it
cat > /etc/apt/apt.conf.d/52owntracks-unattended <<'CONF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
CONF
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF

install -d -m 750 -o root -g mosquitto /etc/mosquitto/certs

# Do not start the broker until deploy-server.sh has installed its config
if [[ -f /etc/mosquitto/conf.d/owntracks.conf ]]; then
  systemctl enable --now mosquitto
else
  systemctl disable --now mosquitto || true
fi

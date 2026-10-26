#!/usr/bin/env bash
# Publish and read back a test message over TLS with a broker user's credentials.
# Requires mosquitto-clients on this machine (sudo apt install mosquitto-clients).
#
# Usage: scripts/test-connection.sh <server-ip> <username>
set -euo pipefail

ip="${1:?usage: test-connection.sh <server-ip> <username>}"
user="${2:?usage: test-connection.sh <server-ip> <username>}"
ca="$(cd "$(dirname "$0")/.." && pwd)/pki/out/ca.crt"
[[ -f "$ca" ]] || { echo "Missing $ca"; exit 1; }

read -rsp "MQTT password for '$user' (Proton Pass item: 'OwnTracks MQTT - $user'): " pw; echo

topic="owntracks/$user/test"
msg="test-$(date +%s)"

# Credentials go in temporary client config files, not on the command line.
# mosquitto_pub/_sub read default options from $XDG_CONFIG_HOME/mosquitto_{pub,sub}.
umask 077
cfg=$(mktemp -d)
trap 'rm -rf "$cfg"' EXIT
printf -- '-h %s\n-p 8883\n--cafile %s\n-u %s\n-P %s\n' "$ip" "$ca" "$user" "$pw" > "$cfg/mosquitto_pub"
cp "$cfg/mosquitto_pub" "$cfg/mosquitto_sub"
unset pw
export XDG_CONFIG_HOME="$cfg"

mosquitto_sub -t "$topic" -C 1 -W 10 > "$cfg/received" &
sub=$!
sleep 1
mosquitto_pub -t "$topic" -m "$msg"
wait "$sub" || true

if grep -qx "$msg" "$cfg/received"; then
  echo "OK: TLS, authentication and ACL work for '$user'."
else
  echo "FAIL: message not received. Check credentials, firewall, and 'sudo journalctl -u mosquitto' on the server."
  exit 1
fi

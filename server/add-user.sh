#!/usr/bin/env bash
# Add or update a Mosquitto user without putting the password on a command line.
# Run on the server: sudo bash add-user.sh <username>
set -euo pipefail

user="${1:?usage: add-user.sh <username>}"
[[ "$user" =~ ^[a-z][a-z0-9_-]{1,31}$ ]] || { echo "Username must be lowercase letters, digits, - or _"; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }

read -rsp "MQTT password for '$user' (Proton Pass item: 'OwnTracks MQTT - $user'): " pw1; echo
read -rsp "Same password again to confirm: " pw2; echo
[[ "$pw1" == "$pw2" ]] || { echo "Passwords do not match."; exit 1; }
(( ${#pw1} >= 20 )) || { echo "Use at least 20 characters."; exit 1; }

umask 077
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%s:%s\n' "$user" "$pw1" > "$tmp"
unset pw1 pw2
mosquitto_passwd -U "$tmp"

touch /etc/mosquitto/passwd
grep -v "^${user}:" /etc/mosquitto/passwd > "$tmp.new" || true
cat "$tmp" >> "$tmp.new"
install -m 600 -o mosquitto -g mosquitto "$tmp.new" /etc/mosquitto/passwd
rm -f "$tmp.new"

systemctl reload mosquitto 2>/dev/null || systemctl restart mosquitto
echo "User '$user' set."

# Operations

All commands run from the repository root on the admin laptop.

```bash
P=$(terraform -chdir=terraform output -raw project_id)
Z=$(terraform -chdir=terraform output -raw zone)
SSH=(gcloud compute ssh owntracks --project="$P" --zone="$Z" --tunnel-through-iap)
```

## Users

| Task | Command |
|---|---|
| Add or change password | `"${SSH[@]}" -- sudo owntracks-add-user <user>` |
| Remove | `"${SSH[@]}" -- "sudo mosquitto_passwd -D /etc/mosquitto/passwd <user> && sudo systemctl reload mosquitto"` |
| List | `"${SSH[@]}" -- sudo cut -d: -f1 /etc/mosquitto/passwd` |

Removing a user stops new connections. Past messages stay encrypted with the shared key; rotate that key on the remaining phones if a phone is lost.

## Certificate renewal

The server certificate is valid for 825 days. Check expiry:

```bash
openssl x509 -in pki/out/server.crt -noout -enddate
```

Renew 30 days before expiry. This reuses the CA, so the phones need no changes:

```bash
pki/make-certs.sh "$(terraform -chdir=terraform output -raw server_ip)"
scripts/deploy-server.sh
```

If the server IP changes, the CA name constraint no longer matches. Delete `pki/out/`, rerun `make-certs.sh` with the new IP, redeploy, and reinstall the CA on both phones.

## Logs and status

```bash
"${SSH[@]}" -- sudo systemctl status mosquitto --no-pager
"${SSH[@]}" -- sudo journalctl -u mosquitto -n 50 --no-pager
```

## Updates

unattended-upgrades installs Debian security updates daily and reboots at 04:00 UTC when required. Mosquitto starts on boot. To update manually:

```bash
"${SSH[@]}" -- "sudo apt-get update && sudo apt-get -y upgrade"
```

## Teardown

```bash
terraform -chdir=terraform destroy
gcloud projects delete "$P"
```

`destroy` releases the static IP; a reserved IP that stays allocated keeps billing. Deleting the project removes the budget's target; delete the budget in the Billing console.

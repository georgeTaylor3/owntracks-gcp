# Security notes

## What each party can see

| Party | Sees | Does not see |
|---|---|---|
| Google | VM metadata, connection times, phone source IPs, encrypted payload sizes | Coordinates, battery, any payload content |
| Anyone on the network path | TLS handshake to the server IP | Credentials, payloads |
| Broker (Mosquitto) | Usernames, topic names, connection times | Coordinates (payloads are encrypted before publishing) |
| Phone holders | Each other's locations | — |

Topic names reveal usernames and device IDs. Use handles that do not identify a person.

## Controls

| Control | Where | Purpose |
|---|---|---|
| Payload encryption (shared key, libsodium secretbox) | OwnTracks on each phone | Broker and cloud provider cannot read locations |
| TLS 1.2+ only, no plaintext listener | `server/mosquitto.conf` | Protects credentials and metadata in transit |
| Private CA with critical `nameConstraints` (server IP only) | `pki/make-certs.sh` | A leaked CA key cannot sign trusted certificates for other hosts |
| CA key encrypted, kept off the server | `pki/out/ca.key` | Server compromise does not expose the CA |
| `allow_anonymous false`, hashed passwords | Mosquitto | Only provisioned users connect |
| Per-user ACL: write own topic, read shared tree | `server/acl` | A user cannot publish as another user |
| Connection and message size limits | `server/mosquitto.conf` | Limits resource use from abuse of the open port |
| Custom VPC, no default rules; ingress 8883 and IAP-range 22 only | `terraform/main.tf` | Minimal exposed surface |
| SSH via IAP with one instance-level key; OS Login off, project SSH keys blocked | `terraform/main.tf` | No public SSH port; IAP requires Google identity and IAM before forwarding |
| No service account on the VM | `terraform/main.tf` | VM compromise yields no Google API credentials |
| Shielded VM (secure boot, vTPM, integrity monitoring) | `terraform/main.tf` | Boot-level tampering detection |
| Unattended security updates | `server/startup.sh` | Patches applied without manual steps |
| Secrets prompted with named password-manager items, never passed as arguments | scripts | No secrets in shell history or process lists |

## Accepted risks

- **Port 8883 open to the internet.** Phones on cellular change IPs, so source filtering is not practical. Mitigated by TLS, password auth, ACLs and connection limits. Adding fail2ban on Mosquitto auth failures is a possible next step.
- **Shared encryption key.** Both phones hold the same symmetric key; a lost phone exposes past and future payloads until the key is rotated on the remaining devices.
- **Metadata.** The provider can see when each phone connects and from which IP.
- **Single VM, no backups.** The broker holds no data that needs restoring; rebuild with `terraform apply` and `deploy-server.sh`.

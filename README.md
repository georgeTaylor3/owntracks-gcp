# owntracks-gcp

Self-hosted, end-to-end encrypted location sharing between an Android phone and an iPhone, using [OwnTracks](https://owntracks.org) and a Mosquitto MQTT broker on a Google Cloud Always Free e2-micro VM.

The broker routes messages but cannot read locations: each phone encrypts its location payload with a shared key before publishing. TLS protects the connection, and a private CA restricted by name constraint to the server's IP authenticates the broker.

```
 Android (OwnTracks)                                 iPhone (OwnTracks)
        │  payload encrypted with shared key                 │
        │  MQTT over TLS 1.2+, port 8883                     │
        └──────────────────────┐        ┌────────────────────┘
                               ▼        ▼
                 ┌───────────────────────────────────┐
                 │ GCP e2-micro, Debian, us-west1    │
                 │  Mosquitto: TLS-only listener     │
                 │  password auth + per-user ACL     │
                 │  no service account               │
                 │  SSH only via IAP, instance key   │
                 └───────────────────────────────────┘
```

## Cost

Inside the Always Free tier for the VM, disk and egress. The reserved external IPv4 address may be billed (about $3–4/month); check the first invoice. `scripts/bootstrap.sh` creates a $5 budget alert.

| Resource | Setting | Always Free |
|---|---|---|
| VM | e2-micro, us-west1 | Yes, one per billing account |
| Disk | 10 GB pd-standard | Yes, up to 30 GB |
| Egress | Standard tier, about 50 MB/month for two phones | Yes, up to 1 GB |
| Static IPv4 | Standard tier | Check billing |

## Repository layout

| Path | Contents |
|---|---|
| `scripts/bootstrap.sh` | Create project, link billing, enable APIs, budget alert |
| `terraform/` | Network, firewall, static IP, VM |
| `server/` | Startup script, Mosquitto config, ACL, user tool |
| `pki/make-certs.sh` | Private CA with IP name constraint, server certificate |
| `scripts/deploy-server.sh` | Push config and certificates to the VM over IAP |
| `scripts/test-connection.sh` | TLS, auth and ACL check from the laptop |
| `docs/` | Phone setup, operations, security notes |

## Prerequisites

- `gcloud` authenticated (`gcloud auth login`) and a billing account
- Terraform 1.6 or later, with `gcloud auth application-default login` for the provider
- `openssl`, and `mosquitto-clients` for the test script
- A password manager for four secrets (names used by the script prompts):

| Proton Pass item | Used for |
|---|---|
| `OwnTracks CA key` | Passphrase on the CA private key |
| `OwnTracks MQTT - <user>` | Broker password, one item per user |
| `OwnTracks encryption key` | Shared payload key, entered on both phones |

## Setup

### 1. Project and billing

```bash
gcloud billing accounts list
scripts/bootstrap.sh <project-id> <billing-account-id>
```

Project IDs are global; pick one with a suffix, e.g. `owntracks-<yymmdd>`.

### 2. Infrastructure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars          # set project_id
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
terraform -chdir=terraform output -raw server_ip
```

The startup script installs Mosquitto and unattended-upgrades on first boot and leaves the broker stopped until step 4. Allow two to three minutes after `apply`.

### 3. Certificates

```bash
pki/make-certs.sh "$(terraform -chdir=terraform output -raw server_ip)"
```

Output goes to `pki/out/` (gitignored). `ca.key` stays on this machine. Back up `pki/out/` with your encrypted backups; you need `ca.key` to renew the server certificate.

### 4. Deploy the broker

```bash
scripts/deploy-server.sh
```

### 5. Add users

One per person. The script prompts for the password; nothing goes on a command line.

```bash
gcloud compute ssh <ssh_user>@owntracks --project=<project-id> --zone=us-west1-b --tunnel-through-iap -- sudo owntracks-add-user <username>
```

Usernames become topic names (`owntracks/<username>/<device>`). Use short lowercase handles.

### 6. Test from the laptop

```bash
sudo apt install mosquitto-clients
scripts/test-connection.sh "$(terraform -chdir=terraform output -raw server_ip)" <username>
```

### 7. Phones

See [docs/phone-setup.md](docs/phone-setup.md).

## Operations

Adding users, certificate renewal, updates and teardown: [docs/operations.md](docs/operations.md).
Threat model and design decisions: [docs/security.md](docs/security.md).
Data flow, trust boundaries and message sequence: [docs/architecture.md](docs/architecture.md).

## License

MIT

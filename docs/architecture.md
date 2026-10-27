# Architecture

Two views: where data flows and which trust boundary each hop crosses, and what happens to one location update from publish to display. Controls are listed per boundary; [security.md](security.md) has the full threat model.

## Data flow and trust boundaries

```mermaid
flowchart LR
    subgraph PA["Phone A: Android, GrapheneOS"]
        A1["OwnTracks (oss build)"]
        A2["Android user CA store:<br/>private CA"]
    end

    subgraph PB["Phone B: iPhone"]
        B1["OwnTracks"]
        B2["iOS trust profile:<br/>private CA, full trust on"]
    end

    subgraph NET["Internet (untrusted)"]
        N1(("cellular / Wi-Fi"))
    end

    subgraph GCP["GCP project (Always Free)"]
        subgraph VPC["Custom VPC: no default firewall rules"]
            FW1{{"Firewall: allow tcp/8883<br/>from any source"}}
            FW2{{"Firewall: allow tcp/22<br/>from IAP range only"}}
            subgraph VM["e2-micro VM: Debian, Shielded VM, no service account"]
                MQ["Mosquitto: TLS-only listener<br/>password auth + ACL"]
                RS[("Retained messages:<br/>ciphertext only")]
            end
        end
        IAP["Identity-Aware Proxy:<br/>checks Google identity + IAM"]
    end

    subgraph LAP["Admin laptop"]
        TF["Terraform"]
        PKI["PKI: CA key encrypted,<br/>never leaves the laptop"]
        CLI["gcloud ssh / scp"]
    end

    A1 -- "MQTT over TLS 1.2+<br/>payload encrypted with shared key" --> N1
    B1 -- "MQTT over TLS 1.2+<br/>payload encrypted with shared key" --> N1
    N1 --> FW1 --> MQ
    MQ --- RS
    A2 -. "verifies server cert" .- A1
    B2 -. "verifies server cert" .- B1

    TF -- "GCP APIs: network, firewall,<br/>static IP, VM" --> GCP
    CLI -- "SSH tunnel" --> IAP --> FW2 --> VM
    PKI -- "server cert + key,<br/>config, ACL (deploy-server.sh)" --> CLI

    classDef untrusted fill:#fdecea,stroke:#c0392b,color:#000
    classDef boundary fill:#fff8e1,stroke:#b7950b,color:#000
    classDef trusted fill:#eaf6ee,stroke:#1e8449,color:#000
    class NET untrusted
    class FW1,FW2,IAP boundary
    class PA,PB,LAP trusted
```

### Controls per boundary

| Boundary | Crossing | Controls |
|---|---|---|
| Phone → Internet | Location update | Payload encrypted on the device with a shared key; TLS 1.2+ to the broker |
| Internet → VPC | MQTT connection | Firewall allows tcp/8883 only; TLS server certificate from a private CA name-constrained to the server IP |
| VPC → Mosquitto | Client session | No anonymous access; per-user password (hashed); ACL: write own tree, read shared tree; connection and packet size limits |
| Mosquitto → storage | Retained message | Broker stores ciphertext; coordinates never exist in plaintext on the server |
| Laptop → VM | Administration | No public SSH: IAP checks Google identity and IAM before forwarding; one instance-level key; project SSH keys blocked |
| Laptop → GCP APIs | Infrastructure | Terraform with short-lived Application Default Credentials, revoked after use; dedicated project with budget alert |
| VM → Google APIs | — | Blocked: no service account attached |

## Location update sequence

```mermaid
sequenceDiagram
    autonumber
    participant A as Phone A (OwnTracks)
    participant M as Mosquitto (VM)
    participant B as Phone B (OwnTracks)

    Note over A: Location fix<br/>(Significant or Move mode)
    A->>A: Encrypt JSON payload with shared key
    A->>M: TLS handshake: verify server cert against private CA
    A->>M: CONNECT username + password
    M->>M: Check password file
    M-->>A: CONNACK
    A->>M: PUBLISH owntracks/user-a/phone (retained, QoS 1)
    M->>M: ACL: user-a may write owntracks/user-a/#35;
    M-->>A: PUBACK
    M->>M: Store retained ciphertext
    B->>M: SUBSCRIBE owntracks/+/+
    M->>M: ACL: user-b may read owntracks/#35;
    M->>B: PUBLISH owntracks/user-a/phone (ciphertext)
    B->>B: Decrypt with shared key
    Note over B: Show user-a's tracker ID on the map
```

### What the server can see

| Field | Visible to broker and cloud provider |
|---|---|
| Coordinates, accuracy, battery, speed, tracker ID | No: inside the encrypted payload |
| Username, device ID (topic name), client ID | Yes |
| Connection times, phone source IPs, message sizes | Yes |

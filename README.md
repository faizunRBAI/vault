# HashiCorp Vault on AWS EC2

A production-bootstrapped HashiCorp Vault server running on a single AWS EC2 instance (Ubuntu 22.04, t3.small) with an Elastic IP, provisioned via Terraform and configured via Ansible. Vault uses the **file storage backend** and listens on **port 8200** with TLS disabled for direct HTTP access.

---

## Architecture

```
Browser / Operator
      │  HTTP :8200
      ▼
 Elastic IP (static)
      │
 EC2 t3.small (Ubuntu 22.04)
 Security Group: :22 + :8200 ← operator IP only
      │
 HashiCorp Vault (systemd)
 Storage: file  →  /opt/vault/data
```

See `.udap/architecture.d2` for the full diagram source.

---

## Stack

| Component       | Detail                                 |
|-----------------|----------------------------------------|
| Cloud           | AWS us-east-1                          |
| Compute         | EC2 t3.small, Ubuntu 22.04 LTS         |
| Networking      | Default VPC, public subnet, Elastic IP |
| Secret Manager  | HashiCorp Vault 1.16+                  |
| Storage Backend | File (`/opt/vault/data`)               |
| Port            | 8200 (HTTP, TLS disabled)              |
| Provisioning    | Terraform ~> 5.0                       |
| Configuration   | Ansible (HashiCorp APT repo)           |
| CI/CD           | GitHub Actions (UDAP pipeline)         |

---

## Prerequisites

- AWS credentials configured (via UDAP Integration page)
- GitHub connected (via UDAP Integration page)
- `MY_IP` pipeline secret set to your operator IP in CIDR notation, e.g. `1.2.3.4/32`

---

## Deploy

Push to `main` — the UDAP pipeline runs automatically:

1. **provision** — Terraform creates EC2, EIP, security group, key pair
2. **configure** — Ansible installs Vault from HashiCorp APT, writes `/etc/vault.d/vault.hcl`, starts systemd service
3. **verify** — curl polls `http://<eip>:8200/v1/sys/health` until Vault responds

The Vault UI URL is printed at the end of the verify stage.

---

## Initialize Vault (one-time, manual)

After the first deploy, Vault is **running but uninitialized**. SSH into the instance and run:

```bash
# SSH in
ssh -i ~/.ssh/deploy_key ubuntu@<your-elastic-ip>

# Initialize Vault (5 key shares, threshold 3)
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator init -key-shares=5 -key-threshold=3
```

**Save the output immediately** — it contains 5 unseal keys and the initial root token. Store them securely (password manager, printed paper, etc.). They **cannot be recovered** if lost.

---

## Unseal Vault

After initialization (or after each restart), Vault starts sealed. Unseal it by providing 3 of the 5 key shares:

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal   # enter Unseal Key 1 when prompted
vault operator unseal   # enter Unseal Key 2
vault operator unseal   # enter Unseal Key 3

vault status            # Sealed: false means ready
```

---

## Access the Vault UI

Open your browser and navigate to:

```
http://<your-elastic-ip>:8200/ui
```

Log in with the **initial root token** from the `vault operator init` output.

> **Security note:** The UI and API are accessible only from the IP address stored in the `MY_IP` pipeline secret. Update that secret and redeploy if your IP changes.

---

## Configuration

| Secret / Variable    | Where set           | Purpose                                   |
|----------------------|---------------------|-------------------------------------------|
| `MY_IP`              | Pipeline secret     | Operator IP allowed on :22 and :8200      |
| `SSH_PUBLIC_KEY`     | Platform (auto)     | EC2 key pair public key                   |
| `SSH_PRIVATE_KEY`    | Platform (auto)     | Used by Ansible to configure the instance |
| `TF_STATE_BUCKET`    | Platform (auto)     | S3 bucket for Terraform state             |
| `PROJECT_NAME`       | Platform (auto)     | Resource name prefix                      |
| `AWS_ACCESS_KEY_ID`  | Platform (auto)     | AWS credentials for Terraform             |
| `AWS_SECRET_ACCESS_KEY` | Platform (auto) | AWS credentials for Terraform             |

---

## Operations

### Check Vault status

```bash
ssh ubuntu@<your-elastic-ip>
export VAULT_ADDR="http://127.0.0.1:8200"
vault status
```

### Restart Vault service

```bash
sudo systemctl restart vault
```

### View Vault logs

```bash
sudo journalctl -u vault -n 100 -f
```

### Vault data directory

All encrypted secrets are stored at `/opt/vault/data` on the instance. Back up this directory before terminating the instance.

### Update MY_IP (if your IP changes)

1. Update the `MY_IP` pipeline secret in the UDAP project settings
2. Redeploy — Terraform will update the security group ingress rule

### Destroy

Trigger the **Destroy** workflow from the UDAP dashboard or GitHub Actions to tear down all AWS resources (EC2, EIP, security group, key pair).

---

## Cost estimate

| Resource       | Approx monthly cost |
|----------------|---------------------|
| EC2 t3.small   | ~$15.00             |
| Elastic IP     | ~$3.60 (attached)   |
| **Total**      | **~$18-20**         |

---

## Security considerations

- TLS is **disabled** — traffic between your browser and Vault is unencrypted. Suitable for evaluation only.
- For production: enable TLS (Let's Encrypt / ACM), restrict root token usage, enable audit logging, and consider Vault auto-unseal via AWS KMS.
- Port 8200 is open **only to your operator IP** via the security group.

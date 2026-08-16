# vault — Build Notes

## Project
- Name: vault
- Cloud: AWS us-east-1
- Target: EC2 (t3.small, Ubuntu 22.04 LTS)
- VCS: GitHub
- Repo: vault
- Branch: main

## Design Decisions

### Network
- Reusing default VPC (vpc-06e83f344275bbd92, 172.31.0.0/16) — probe confirmed it exists with 6 subnets
- Elastic IP attached so the public IP is stable across stop/start cycles (important for security group ingress + browser bookmarks)
- Security group restricts :22 (SSH) and :8200 (Vault) to MY_IP secret only — no 0.0.0.0/0 exposure

### Vault Configuration
- File storage backend at /opt/vault/data — simple, no external dependency, appropriate for single-node eval
- TLS disabled per user request — listener on 0.0.0.0:8200 with tls_disable=1
- ui=true — Vault web UI enabled
- api_addr set to http://0.0.0.0:8200 so Vault reports the correct self-referential address

### Installation Method
- HashiCorp official APT repository (apt.releases.hashicorp.com) — signed packages, correct for Ubuntu 22.04 LTS
- GPG key downloaded via curl + gpg --dearmor (idempotent via `creates:` guard)
- vault package installs vault user/group and systemd unit automatically

### Security Group
- MY_IP is a pipeline secret (CIDR /32) — operator sets it before deploying
- No default value — deployment will fail fast if MY_IP is not set (by design)

### Pitfall avoidance
- cache_valid_time: 0 on apt update (NOT cache_valid_time: 3600) — cloud images have stale apt cache; see platform pitfall #1c
- apt_repository task with update_cache: true to refresh after adding HashiCorp repo
- All module calls use ansible.builtin.* — no community.general required for this playbook
- EIP output used for downstream stages, not instance ephemeral IP — see platform contract pitfall #4

## Pipeline
- provision: Terraform provisions EC2 + EIP + SG + key pair; exports instance_public_ip + instance_id
- configure: Reads IP from TF state (self-sufficient job rule), installs Vault via Ansible
- verify: Reads IP from TF state, polls /v1/sys/health with 15 retries × 15s delay (225s window)
  - Vault health endpoint returns 200 for uninit + sealed states (uninitcode=200&sealedcode=200) so verify passes even before operator init

## Post-Deploy Manual Steps (documented in README)
1. SSH in and run: vault operator init -key-shares=5 -key-threshold=3
2. Save the 5 unseal keys and root token securely
3. Unseal with 3 of 5 keys: vault operator unseal (×3)
4. Browse to http://<eip>:8200/ui

## Status
- [ ] validate_project
- [ ] test_project
- [ ] create_repo_and_push
- [ ] set_pipeline_secret MY_IP
- [ ] deploy

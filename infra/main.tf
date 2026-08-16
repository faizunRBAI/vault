# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Ubuntu 22.04 LTS (Jammy) – official Canonical AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── SSH Key Pair ───────────────────────────────────────────────────────────────

resource "aws_key_pair" "vault" {
  key_name   = "${var.project_name}-vault-key"
  public_key = var.ssh_public_key

  tags = {
    Name      = "${var.project_name}-vault-key"
    Project   = var.project_name
    ManagedBy = "udap"
  }
}

# ── Security Group ─────────────────────────────────────────────────────────────

resource "aws_security_group" "vault" {
  name        = "${var.project_name}-vault-sg"
  description = "Vault server: SSH and Vault API/UI from operator IP only"
  vpc_id      = data.aws_vpc.default.id

  # SSH from operator IP
  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Vault API + UI from operator IP
  ingress {
    description = "Vault API and UI from operator"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow all outbound (package installs, HashiCorp repo, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name      = "${var.project_name}-vault-sg"
    Project   = var.project_name
    ManagedBy = "udap"
  }
}

# ── EC2 Instance ───────────────────────────────────────────────────────────────

resource "aws_instance" "vault" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.vault.id]
  key_name                    = aws_key_pair.vault.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.project_name}-vault"
    Project   = var.project_name
    ManagedBy = "udap"
  }
}

# ── Elastic IP ─────────────────────────────────────────────────────────────────

resource "aws_eip" "vault" {
  domain = "vpc"

  tags = {
    Name      = "${var.project_name}-vault-eip"
    Project   = var.project_name
    ManagedBy = "udap"
  }
}

resource "aws_eip_association" "vault" {
  instance_id   = aws_instance.vault.id
  allocation_id = aws_eip.vault.id
}

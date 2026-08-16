output "instance_public_ip" {
  description = "Elastic IP address assigned to the Vault EC2 instance."
  value       = aws_eip.vault.public_ip
}

output "instance_id" {
  description = "EC2 instance ID of the Vault server."
  value       = aws_instance.vault.id
}

output "vault_ui_url" {
  description = "Direct URL to the Vault web UI."
  value       = "http://${aws_eip.vault.public_ip}:8200/ui"
}

output "security_group_id" {
  description = "ID of the Vault security group."
  value       = aws_security_group.vault.id
}

output "instance_public_ip" {
  description = "Static public IP address of the VM (stable across stop/start)"
  value       = azurerm_public_ip.home_energy_tracker.ip_address
}

output "vm_id" {
  description = "Azure VM resource ID"
  value       = azurerm_linux_virtual_machine.home_energy_tracker.id
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ~/.ssh/home-energy-tracker-azure-key ${var.admin_username}@${azurerm_public_ip.home_energy_tracker.ip_address}"
}

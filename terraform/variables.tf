variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "France Central"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B1s" # 1 vCPU / 1GB RAM - free-tier eligible (750h/month for 12 months). Tight for 7 JVM services + Kafka + MySQL + InfluxDB + Keycloak; expect to trim JVM heap sizes further, as done for the AWS t3.small setup.
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "public_key_path" {
  description = "Path to your local SSH public key (.pub file). Must be RSA — Azure does not support ed25519 keys for admin_ssh_key."
  type        = string
  default     = "~/.ssh/home-energy-tracker-azure-key.pub"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR format, e.g. 82.123.45.67/32 (get it from https://whatismyip.com)"
  type        = string
  default     = "0.0.0.0/0"
}

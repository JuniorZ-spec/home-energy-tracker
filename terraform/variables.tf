variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "France Central"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s" # 2 vCPU / 4GB RAM - needed for 7 JVM services + Kafka + MySQL + InfluxDB + Keycloak
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "public_key_path" {
  description = "Path to your local SSH public key (.pub file)"
  type        = string
  default     = "~/.ssh/home-energy-tracker-key.pub"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR format, e.g. 82.123.45.67/32 (get it from https://whatismyip.com)"
  type        = string
  default     = "0.0.0.0/0"
}

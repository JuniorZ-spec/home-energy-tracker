# --- Resource group ---
resource "azurerm_resource_group" "home_energy_tracker" {
  name     = "home-energy-tracker-rg"
  location = var.location

  tags = {
    Project = "home-energy-tracker"
  }
}

# --- Network ---
resource "azurerm_virtual_network" "home_energy_tracker" {
  name                = "home-energy-tracker-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.home_energy_tracker.location
  resource_group_name = azurerm_resource_group.home_energy_tracker.name
}

resource "azurerm_subnet" "home_energy_tracker" {
  name                 = "home-energy-tracker-subnet"
  resource_group_name  = azurerm_resource_group.home_energy_tracker.name
  virtual_network_name = azurerm_virtual_network.home_energy_tracker.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- Public IP (Static SKU, stable across stop/start) ---
resource "azurerm_public_ip" "home_energy_tracker" {
  name                = "home-energy-tracker-ip"
  location            = azurerm_resource_group.home_energy_tracker.location
  resource_group_name = azurerm_resource_group.home_energy_tracker.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Project = "home-energy-tracker"
  }
}

# --- Network Security Group ---
resource "azurerm_network_security_group" "home_energy_tracker" {
  name                = "home-energy-tracker-nsg"
  location            = azurerm_resource_group.home_energy_tracker.location
  resource_group_name = azurerm_resource_group.home_energy_tracker.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ApiGateway"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Grafana"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Prometheus"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "KafkaUI"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8070"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Mailpit"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8025"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Keycloak"
    priority                   = 160
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8091"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  tags = {
    Project = "home-energy-tracker"
  }
}

# --- NIC + static public IP + NSG association ---
resource "azurerm_network_interface" "home_energy_tracker" {
  name                = "home-energy-tracker-nic"
  location            = azurerm_resource_group.home_energy_tracker.location
  resource_group_name = azurerm_resource_group.home_energy_tracker.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.home_energy_tracker.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.home_energy_tracker.id
  }
}

resource "azurerm_network_interface_security_group_association" "home_energy_tracker" {
  network_interface_id     = azurerm_network_interface.home_energy_tracker.id
  network_security_group_id = azurerm_network_security_group.home_energy_tracker.id
}

# --- Ubuntu 22.04 LTS VM ---
resource "azurerm_linux_virtual_machine" "home_energy_tracker" {
  name                = "home-energy-tracker-vm"
  location            = azurerm_resource_group.home_energy_tracker.location
  resource_group_name = azurerm_resource_group.home_energy_tracker.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.home_energy_tracker.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb          = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # System-assigned identity, closest Azure equivalent to the AWS SSM setup:
  # lets Azure Run Command / Azure Monitor operate on the VM via the control
  # plane and RBAC, without opening extra inbound network paths.
  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              chmod a+r /etc/apt/keyrings/docker.asc
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              usermod -aG docker ${var.admin_username}
              systemctl enable docker
              systemctl start docker
              EOF
  )

  tags = {
    Name    = "home-energy-tracker-prod"
    Project = "home-energy-tracker"
  }
}

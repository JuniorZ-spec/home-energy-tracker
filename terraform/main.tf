# --- Security Group ---
resource "aws_security_group" "home_energy_tracker_sg" {
  name        = "home-energy-tracker-sg"
  description = "Security group for Home Energy Tracker EC2 instance"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "API Gateway"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Kafka UI"
    from_port   = 8070
    to_port     = 8070
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Mailpit"
    from_port   = 8025
    to_port     = 8025
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Keycloak"
    from_port   = 8091
    to_port     = 8091
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "home-energy-tracker-sg"
    Project = "home-energy-tracker"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "home-energy-tracker-key"
  public_key = file(var.public_key_path)
}

# --- Ubuntu 22.04 LTS AMI ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "home_energy_tracker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.home_energy_tracker_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  lifecycle {
    ignore_changes = [ami]
  }

  user_data = <<-EOF
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
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              EOF

  tags = {
    Name    = "home-energy-tracker-prod"
    Project = "home-energy-tracker"
  }
}

# --- Elastic IP (keeps a stable public IP across stop/start) ---
resource "aws_eip" "home_energy_tracker" {
  instance = aws_instance.home_energy_tracker.id
  domain   = "vpc"

  tags = {
    Name    = "home-energy-tracker-eip"
    Project = "home-energy-tracker"
  }
}

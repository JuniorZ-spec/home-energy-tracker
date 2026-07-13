output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.home_energy_tracker.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.home_energy_tracker.id
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ~/.ssh/home-energy-tracker-key ubuntu@${aws_instance.home_energy_tracker.public_ip}"
}

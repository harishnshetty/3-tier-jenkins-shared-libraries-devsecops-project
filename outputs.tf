output "public_ip" {
  value = aws_spot_instance_request.cheap_worker.public_ip
}
output "ssh_command" {
  value = "ssh -i 'new-keypair.pem' ubuntu@${aws_spot_instance_request.cheap_worker.public_dns}"
}

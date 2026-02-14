

resource "aws_security_group" "jenkins-worker-sg" {
  name        = "jenkins-worker-sg"
  description = "Allow SSH and HTTP access"

  tags = {
    "Name" = "spot-sg"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Request a spot instance at $0.03
# resource "aws_spot_instance_request" "jenkins_worker" {
#   ami = "ami-019715e0d74f695be"
#   #   spot_price             = "0.02"

#   instance_type = "c5a.xlarge"

#   root_block_device {
#     volume_size = 25
#     volume_type = "gp3"
#   }
#   key_name = "new-keypair"

#   vpc_security_group_ids = [aws_security_group.jenkins-worker-sg.id]
#   user_data              = file("script.sh")
#   tags = {
#     Name = "Spot-Worker"
#   }

#   wait_for_fulfillment = true
#   depends_on           = [aws_security_group.jenkins-worker-sg]

#   lifecycle {
#     ignore_changes = [ami, spot_price, vpc_security_group_ids]
#   }
# }

# resource "aws_ec2_tag" "jenkins_worker_tag" {
#   resource_id = aws_spot_instance_request.jenkins_worker.spot_instance_id
#   key         = "Name"
#   value       = "Spot-Worker"
# }


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  #   ami                    = ami-019715e0d74f695be

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "c5a.xlarge"
  vpc_security_group_ids = [aws_security_group.jenkins-worker-sg.id]
  key_name               = "new-keypair"
  user_data              = file("script.sh")
  tags = {
    Name = "jenkins-server"
  }
  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }
}

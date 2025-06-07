# Bastion Host for Database Access
# This allows secure SSH tunneling to access the private RDS instance

# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.app_name}-bastion-"
  vpc_id      = aws_vpc.transcripts_vpc.id

  # SSH access (restrict to your IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Restrict to your IP
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.app_name}-bastion-sg"
    Environment = var.environment
  }
}

# Update RDS Security Group to allow bastion access
resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
  description              = "PostgreSQL access from bastion host"
}

# Key pair for bastion host (you'll need to create this in AWS Console first)
# Or create one locally: ssh-keygen -t rsa -b 2048 -f ~/.ssh/transcripts-bastion

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion Host EC2 Instance
resource "aws_instance" "bastion" {
  count = var.environment == "dev" ? 1 : 0 # Only create for dev environment

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  key_name                    = var.bastion_key_name # You need to define this variable
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y postgresql15
              EOF

  tags = {
    Name        = "${var.app_name}-bastion"
    Environment = var.environment
    Purpose     = "Database access"
  }
} 
# VPC Configuration for RDS
resource "aws_vpc" "transcripts_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.app_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "transcripts_igw" {
  vpc_id = aws_vpc.transcripts_vpc.id

  tags = {
    Name        = "${var.app_name}-igw"
    Environment = var.environment
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  count  = 2
  domain = "vpc"

  tags = {
    Name        = "${var.app_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.transcripts_igw]
}

# Public Subnets (for NAT Gateways)
resource "aws_subnet" "public_subnets" {
  count = 2

  vpc_id                  = aws_vpc.transcripts_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.app_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Private Subnets (for Lambda functions)
resource "aws_subnet" "private_subnets_lambda" {
  count = 2

  vpc_id            = aws_vpc.transcripts_vpc.id
  cidr_block        = "10.0.${count.index + 5}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.app_name}-lambda-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Private Subnets (for RDS)
resource "aws_subnet" "private_subnets" {
  count = 2

  vpc_id            = aws_vpc.transcripts_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.app_name}-rds-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat_gw" {
  count = 2

  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name        = "${var.app_name}-nat-gw-${count.index + 1}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.transcripts_igw]
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.transcripts_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.transcripts_igw.id
  }

  tags = {
    Name        = "${var.app_name}-public-rt"
    Environment = var.environment
  }
}

# Route Tables for Private Subnets (Lambda)
resource "aws_route_table" "private_rt_lambda" {
  count = 2

  vpc_id = aws_vpc.transcripts_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }

  tags = {
    Name        = "${var.app_name}-lambda-private-rt-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Tables for Private Subnets (RDS) - no internet access needed
resource "aws_route_table" "private_rt_rds" {
  vpc_id = aws_vpc.transcripts_vpc.id

  tags = {
    Name        = "${var.app_name}-rds-private-rt"
    Environment = var.environment
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public_rta" {
  count = 2

  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table Associations for Private Subnets (Lambda)
resource "aws_route_table_association" "private_rta_lambda" {
  count = 2

  subnet_id      = aws_subnet.private_subnets_lambda[count.index].id
  route_table_id = aws_route_table.private_rt_lambda[count.index].id
}

# Route Table Associations for Private Subnets (RDS)
resource "aws_route_table_association" "private_rta_rds" {
  count = 2

  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt_rds.id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# DB Subnet Group
resource "aws_db_subnet_group" "transcripts_db_subnet_group" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id

  tags = {
    Name        = "${var.app_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.app_name}-rds-"
  vpc_id      = aws_vpc.transcripts_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "PostgreSQL access from Lambda functions"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.app_name}-rds-sg"
    Environment = var.environment
  }
}

# Security Group for Lambda Functions
resource "aws_security_group" "lambda_sg" {
  name_prefix = "${var.app_name}-lambda-"
  vpc_id      = aws_vpc.transcripts_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.app_name}-lambda-sg"
    Environment = var.environment
  }
}

# Random password for RDS (will be stored in Secrets Manager)
resource "random_password" "rds_password" {
  length  = 32
  special = true
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "transcripts_postgres" {
  identifier = "${var.app_name}-postgres-${var.environment}"

  # Engine configuration
  engine         = "postgres"
  engine_version = "15.10"
  instance_class = var.environment == "prod" ? "db.t3.small" : "db.t3.micro"

  # Database configuration
  allocated_storage     = var.environment == "prod" ? 100 : 20
  max_allocated_storage = var.environment == "prod" ? 1000 : 100
  storage_type          = "gp2"
  storage_encrypted     = true

  # Database credentials
  db_name  = "transcripts"
  username = "transcripts_admin"
  password = random_password.rds_password.result

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.transcripts_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window          = "07:00-09:00"
  maintenance_window     = "Sun:09:00-Sun:11:00"

  # Monitoring
  performance_insights_enabled = var.environment == "prod" ? true : false
  monitoring_interval         = var.environment == "prod" ? 60 : 0

  # Deletion protection
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.app_name}-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  tags = {
    Name        = "${var.app_name}-postgres"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [password]
  }
}

# Store RDS credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.environment}/transcripts/postgres-db"
  description             = "PostgreSQL credentials for transcripts API ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name        = "${var.app_name}-rds-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.transcripts_postgres.username
    password = random_password.rds_password.result
    engine   = "postgres"
    host     = aws_db_instance.transcripts_postgres.endpoint
    port     = aws_db_instance.transcripts_postgres.port
    dbname   = aws_db_instance.transcripts_postgres.db_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
} 
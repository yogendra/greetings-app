terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
variable "prefix" {
  default = "lab0"
  type = string
  description = "prefix for all the resource"
}
variable "region" {
  default = "ap-southeast-1"
  type = string
  description = "AWS Region"
}
variable "tags" {
  default = {
    yb_owner = "yrampuria"
    yb_dept = "sales"
    yb_task = "learning"
  }
  description = "Tags for resources"
  type = map(string)
}
locals {
  tags = merge({
      app-env = var.prefix
      app-type = "greetings-app"
    }, var.tags)
}
provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}
# Random password generation for RDS
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}
# Create VPC
resource "aws_vpc" "greetings_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "${var.prefix}-greetings-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.greetings_vpc.id

  tags = {
    Name = "${var.prefix}-greetings-igw"
  }
}

# Create public subnets (one per AZ)
resource "aws_subnet" "public_subnet" {
  for_each = toset(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.greetings_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.greetings_vpc.cidr_block, 8, index(data.aws_availability_zones.available.names, each.value))
  availability_zone = each.value

  tags = {
    Name = "${var.prefix}-greetings-public-${each.value}"
  }
}

# Create public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.greetings_vpc.id

  tags = {
    Name = "${var.prefix}-greetings-public-rt"
  }
}

# Create public route
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Associate public subnets to public route table
resource "aws_route_table_association" "public_subnet_association" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create private subnets (one per AZ)
resource "aws_subnet" "private_subnet" {
  for_each = toset(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.greetings_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.greetings_vpc.cidr_block, 8, 16 + index(data.aws_availability_zones.available.names, each.value))
  availability_zone = each.value

  tags = {
    Name = "${var.prefix}-greetings-private-${each.value}"
  }
}

# Create private route table
resource "aws_route_table" "private_route_table" {
  for_each = toset(data.aws_availability_zones.available.names)
  vpc_id = aws_vpc.greetings_vpc.id

  tags = {
    Name = "${var.prefix}-greetings-private-rt-${each.value}"
  }
}

# Create a NAT gateway route in the private route table for each AZ
resource "aws_route" "private_nat_route" {
  for_each = toset(data.aws_availability_zones.available.names)
  route_table_id         = aws_route_table.private_route_table[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

# Associate private subnets to private route table
resource "aws_route_table_association" "private_subnet_association" {
  for_each = toset(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private_route_table[each.key].id
}


# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  for_each = toset(data.aws_availability_zones.available.names)
  tags = {
    Name = "${var.prefix}-greetings-nat-eip-${each.value}"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  for_each      = aws_eip.nat_eip
  allocation_id = each.value.id
  subnet_id     = aws_subnet.public_subnet[each.key].id

  tags = {
    Name = "${var.prefix}-greetings-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.gw]
}


#Data for available azs
data "aws_availability_zones" "available" {}

# Create Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "${var.prefix}-greetings-ec2-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.greetings_vpc.id

  ingress {
    from_port   = 8000
    to_port     = 8000
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


# Create IAM Role for EC2 SSM Access
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
# Data source to fetch the latest Ubuntu 22.04 Jammy AMI

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240411"]
  }

  owners = ["099720109477"] # Canonical
}
# Create Launch Template
resource "aws_launch_template" "greetings_template" {
  name_prefix   = "${var.prefix}-greetings-template-"
  description   = "Launch template for Greetings Board app"
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm_instance_profile.name
  }

  image_id               = data.aws_ami.ubuntu.id  # Use the fetched AMI ID
  instance_type          = "t3.micro"

  instance_market_options {  # Enable Spot Instances
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"  # Choose your Spot Instance type
    }
  }

  network_interfaces {
    security_groups             = [aws_security_group.ec2_sg.id]
    associate_public_ip_address = false
    subnet_id                   = aws_subnet.private_subnet["ap-southeast-1a"].id
  }
  user_data = base64encode(<<EOF
    #cloud-config
    runcmd:
      - curl -sSL get.docker.com | bash
      - sudo usermod -a -G docker ubuntu
      - sudo -iu ubuntu docker run -d --restart=unless-stopped -p 8000:8000 --name greetings-container -e POSTGRES_HOST=${aws_db_instance.greetings_db.address} -e POSTGRES_PORT=${aws_db_instance.greetings_db.port} -e POSTGRES_USER=${aws_db_instance.greetings_db.username} -e POSTGRES_PASSWORD=${aws_db_instance.greetings_db.password} -e POSTGRES_DB=${aws_db_instance.greetings_db.db_name} yogendra/greetings-app:latest

    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, { Name = "${var.prefix}-greetings-app" })
  }
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.tags, { Name = "${var.prefix}-greetings-app" })
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge(local.tags, { Name = "${var.prefix}-greetings-app" })
  }
}

# Create Auto Scaling Group to deploy EC2 instances across AZs
resource "aws_autoscaling_group" "greetings_asg" {
  name = "${var.prefix}-greetings-asg"

  launch_template {
    id      = aws_launch_template.greetings_template.id
    version = "$Latest"
  }

  vpc_zone_identifier = [
    aws_subnet.private_subnet["ap-southeast-1a"].id,
    aws_subnet.private_subnet["ap-southeast-1b"].id,
    aws_subnet.private_subnet["ap-southeast-1c"].id
  ]

  min_size = 1
  max_size = 3
  desired_capacity = 2
  target_group_arns = [ aws_lb_target_group.greetings_tg.arn ]


}

# Create RDS PostgreSQL instance
resource "aws_db_instance" "greetings_db" {
  identifier              = "${var.prefix}-greetings-db"
  engine                  = "postgres"
  engine_version          = "14"  # Latest PostgreSQL version
  instance_class          = "db.t3.micro"
  allocated_storage       = 20  # Adjust storage as needed
  username                = "postgres"
  password                = random_password.db_password.result  # Generate a random password
  db_name                 = "greetings_db"
  multi_az                = true  # Enable multi-AZ for high availability
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  db_subnet_group_name       = aws_db_subnet_group.greetings_db_subnet_group.name

  skip_final_snapshot     = true

  tags = {
    Name = "${var.prefix}-greetings-db"
  }
}

# Create DB subnet group
resource "aws_db_subnet_group" "greetings_db_subnet_group" {
  name       = "${var.prefix}-greetings-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet["ap-southeast-1a"].id,
    aws_subnet.private_subnet["ap-southeast-1b"].id,
    aws_subnet.private_subnet["ap-southeast-1c"].id
  ]
  tags = {
    Name = "${var.prefix}-greetings-db-subnet-group"
  }
}

# Create a security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "${var.prefix}-greetings-rds-sg"
  description = "Allow inbound traffic from EC2"
  vpc_id      = aws_vpc.greetings_vpc.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [ aws_security_group.ec2_sg.id]
  }
}



# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.prefix}-greetings-alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.greetings_vpc.id

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
# TLS Private Key for our project
resource "tls_private_key" "app-tls-pkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Certificate for AWS ALB
resource "tls_self_signed_cert" "self_signed" {
  private_key_pem = tls_private_key.app-tls-pkey.private_key_pem
  subject {
    common_name = "Greetings App (${var.prefix}-greetings-app)"
  }
  validity_period_hours = 1 * 30 * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  # dns_names = ["test.example.com"]
}

# Put the self signed cert on AWS ACM
resource "aws_acm_certificate" "self_signed" {
  private_key      = tls_self_signed_cert.self_signed.private_key_pem
  certificate_body = tls_self_signed_cert.self_signed.cert_pem
}

# Attach AWS ACM Cert to ALB listener
resource "aws_lb_listener_certificate" "web_app_cert" {
  listener_arn    = aws_lb_listener.front_end.arn
  certificate_arn = aws_acm_certificate.self_signed.arn
}

# Application Load Balancer
resource "aws_lb" "greetings_alb" {
  name               = "${var.prefix}-greetings-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]
}

# Target Group for EC2 instances
resource "aws_lb_target_group" "greetings_tg" {
  name        = "${var.prefix}-greetings-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.greetings_vpc.id
  target_type = "instance"

  health_check {
    path = "/"  # Health check path for your FastAPI app
  }
}


# Listener on ALB
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.greetings_alb.arn
  port              = 443
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.greetings_tg.arn
  }
}

resource "aws_lb_listener" "front_end_http" {
  load_balancer_arn = aws_lb.greetings_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Output ALB DNS name
output "alb_dns_name" {
  value = aws_lb.greetings_alb.dns_name
}

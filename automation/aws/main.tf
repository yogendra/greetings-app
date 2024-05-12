terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = {
      app = "greetings-app"
      yb_owner = "yrampuria"
      yb_dept = "sales"
      yb_task = "learning"
    }
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
    Name = "greetings-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.greetings_vpc.id

  tags = {
    Name = "greetings-igw"
  }
}

# Create public subnets (one per AZ)
resource "aws_subnet" "public_subnet" {
  for_each = data.aws_availability_zones.available.names
  vpc_id            = aws_vpc.greetings_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.greetings_vpc.cidr_block, 8, index(data.aws_availability_zones.available.names, each.value))
  availability_zone = each.value

  tags = {
    Name = "greetings-public-${each.value}"
  }
}

# Create public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.greetings_vpc.id

  tags = {
    Name = "greetings-public-rt"
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
  for_each = data.aws_availability_zones.available.names
  vpc_id            = aws_vpc.greetings_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.greetings_vpc.cidr_block, 8, 16 + index(data.aws_availability_zones.available.names, each.value))
  availability_zone = each.value

  tags = {
    Name = "greetings-private-${each.value}"
  }
}

# Create private route table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.greetings_vpc.id

  tags = {
    Name = "greetings-private-rt"
  }
}

# Create a NAT gateway route in the private route table for each AZ
resource "aws_route" "private_nat_route" {
  for_each         = aws_subnet.private_subnet
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

# Associate private subnets to private route table
resource "aws_route_table_association" "private_subnet_association" {
  for_each = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}


# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  for_each = toset(data.aws_availability_zones.available.names)
  tags = {
    Name = "greetings-nat-eip-${each.value}"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  for_each      = aws_eip.nat_eip
  allocation_id = each.value.id
  subnet_id     = aws_subnet.public_subnet[each.key].id

  tags = {
    Name = "greetings-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.gw]
}


#Data for available azs
data "aws_availability_zones" "available" {}

# Create Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "greetings-ec2-sg"
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
  name_prefix   = "greetings-template-"
  description   = "Launch template for Greetings Board app"
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_role.ec2_ssm_role.name
  }

  image_id               = data.aws_ami.ubuntu.id  # Use the fetched AMI ID
  instance_type          = "t3.micro"

  instance_market_options {  # Enable Spot Instances
    market_type = "spot"
    spot_options {
      spot_instance_type = "persistent"  # Choose your Spot Instance type
    }
  }

  network_interfaces {
    security_groups             = [aws_security_group.ec2_sg.id]
    associate_public_ip_address = false
    subnet_id                   = aws_subnet.private_subnet["ap-southeast-1a"].id
  }
  user_data = <<EOF
    #cloud-config
    runcmd:
      - curl -sSL get.docker.com | bash
      - sudo usermod -a -G docker ubuntu
      - exec su -l ubuntu docker run -d -p 8000:8000 --name greetings-container -e POTGRES_

    EOF
}

# Create Auto Scaling Group to deploy EC2 instances across AZs
resource "aws_autoscaling_group" "greetings_asg" {
  name = "greetings-asg"

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

}

# Create RDS PostgreSQL instance
resource "aws_db_instance" "greetings_db" {
  identifier              = "greetings-db"
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
    Name = "greetings-db"
  }
}

# Create DB subnet group
resource "aws_db_subnet_group" "greetings_db_subnet_group" {
  name       = "greetings-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet["ap-southeast-1a"].id,
    aws_subnet.private_subnet["ap-southeast-1b"].id,
    aws_subnet.private_subnet["ap-southeast-1c"].id
  ]
  tags = {
    Name = "greetings-db-subnet-group"
  }
}

# Create a security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "greetings-rds-sg"
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
  name        = "greetings-alb-sg"
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

# Application Load Balancer
resource "aws_lb" "greetings_alb" {
  name               = "greetings-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]
}

# Target Group for EC2 instances
resource "aws_lb_target_group" "greetings_tg" {
  name        = "greetings-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.greetings_vpc.id
  target_type = "instance"

  health_check {
    path = "/"  # Health check path for your FastAPI app
  }
}

# Attach EC2 instances to the target group (dynamically based on ASG)
resource "aws_lb_target_group_attachment" "greetings_tg_attachment" {
  for_each = aws_autoscaling_group.greetings_asg.instances
  target_group_arn = aws_lb_target_group.greetings_tg.arn
  target_id        = each.value.id
  port             = 8000
}

# Listener on ALB
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.greetings_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.greetings_tg.arn
  }
}

# Output ALB DNS name
output "alb_dns_name" {
  value = aws_lb.greetings_alb.dns_name
}

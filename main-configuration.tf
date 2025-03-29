# AWS Provider Configuration
provider "aws" {
  region  = "eu-central-1"
  profile = var.profile_id

  default_tags {
    tags = {
      Project   = "Terraform Deployment"
      ManagedBy = "Terraform"
    }
  }
}

# Create the VPC dynamically
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Create public subnets, for each a different availability zone
variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  default = {
    subnet1 = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "eu-central-1a"
    },
    subnet2 = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "eu-central-1b"
    }
  }
}

resource "aws_subnet" "public_subnets" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-${each.key}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# Create a route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main-route-table"
  }
}

# Associate the route table with all subnets dynamically
resource "aws_route_table_association" "subnet_association" {
  for_each = aws_subnet.public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.main.id
}

# Create a Security Group
resource "aws_security_group" "allow_web_traffic" {
  name        = "terraform-firewall"
  description = "Managed by Terraform"
  vpc_id      = aws_vpc.main.id

  # Ingress Rules: Allow HTTP (IPv4)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all IPv4 addresses
  }

  # Egress Rule: Allow All Outbound Traffic (IPv4)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]  # Allow all IPv4 addresses
  }
}

# Add IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "EC2InstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2InstanceProfile"
  role = aws_iam_role.ec2_role.name
}

# Define the Launch Template
resource "aws_launch_template" "my_launch_template" {
  name          = "my-launch-template"
  image_id      = var.ami
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.allow_web_traffic.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "auto-scaled-ec2"
    }
  }
}

# Configure a Target Group
resource "aws_lb_target_group" "my_target_group" {
  name          = "my-target-group"
  port          = 80
  protocol      = "HTTP"
  vpc_id        = aws_vpc.main.id
  target_type   = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "MyTargetGroup"
  }
}

# Configure the Elastic Load Balancer (ALB)
resource "aws_lb" "my_alb" {
  name                      = "my-alb"
  internal                  = false
  load_balancer_type        = "application"
  security_groups           = [aws_security_group.allow_web_traffic.id]

  subnets = flatten([for subnet in aws_subnet.public_subnets : subnet.id])

  enable_deletion_protection        = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "MyALB"
  }
}

# Configure the Listener for HTTP traffic (Port 80)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "my_asg" {
  desired_capacity     = 2
  max_size             = 5
  min_size             = 2
  vpc_zone_identifier  = flatten([for subnet in aws_subnet.public_subnets : subnet.id])
  health_check_type    = "EC2"
  health_check_grace_period = 300
  force_delete         = true

  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.my_target_group.arn]

  tag {
    key                 = "Name"
    value               = "auto-scaled-ec2"
    propagate_at_launch = true
  }
}

# Output information about ASG
output "asg_name" {
  value       = aws_autoscaling_group.my_asg.name
  description = "The name of the Auto Scaling Group"
}

# List of instance IDs with AWS data source
data "aws_instances" "asg_instances" {
  filter {
    name   = "tag:Name"
    values = ["auto-scaled-ec2"]
  }
}

output "asg_instances" {
  value       = data.aws_instances.asg_instances.ids
  description = "List of instance IDs in the Auto Scaling Group"
}

# Output information about Load Balancer
output "alb_dns_name" {
  value       = aws_lb.my_alb.dns_name
  description = "DNS name of the Application Load Balancer (ALB)"
}

# Output information about security group
output "security_group_id" {
  value       = aws_security_group.allow_web_traffic.id
  description = "ID of the Security Group used by EC2 and ALB"
}

# Output information about VPC
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}

# AWS Provider Configuration
provider "aws" {
  region  = "eu-central-1"
  profile = var.profile_id
}

# Create the VPC dynamically
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyNewVPC"
  }
}

# Create a public subnet in availability zone A
resource "aws_subnet" "my_subnet_a" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.subnet_a_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "MyPublicSubnetA"
  }
}

# Create a public subnet in availability zone B
resource "aws_subnet" "my_subnet_b" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.subnet_b_cidr
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "MyPublicSubnetB"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# Create a public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "MyPublicRouteTable"
  }
}

# Associate the public route table with subnet A
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.my_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate the public route table with subnet B
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.my_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group Configuration
resource "aws_security_group" "allow_web_traffic" {
  name        = "terraform-firewall"
  description = "Managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id

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

# EC2 Instance attached to the new subnet and security group
resource "aws_instance" "myec2" {
  ami             = "ami-0b74f796d330ab49c"  # Define the AMI for the EC2 instance
  instance_type   = "t2.micro"                # Define the EC2 instance type
  subnet_id = aws_subnet.my_subnet_a.id      # Use the subnet ID from the new subnet
  associate_public_ip_address = true          # Assign a public IP to the instance

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
  EOF

  vpc_security_group_ids = [aws_security_group.allow_web_traffic.id]  # Attach the security group

  tags = {
    Name = "my-first-ec2"
  }
}

# Add a Second EC2 Instance in a different Availability Zone
resource "aws_instance" "myec2_b" {
  ami             = "ami-0b74f796d330ab49c"  # Define the AMI for the EC2 instance
  instance_type   = "t2.micro"                # Define the EC2 instance type
  subnet_id       = aws_subnet.my_subnet_b.id  # Use a new subnet for the second instance in a different availability zone
  associate_public_ip_address = true          # Assign a public IP to the instance

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
  EOF

  vpc_security_group_ids = [aws_security_group.allow_web_traffic.id]  # Attach the security group

  tags = {
    Name = "my-second-ec2"
  }
}

# Configure a Target Group
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id  # Use the ID of the dynamically created VPC

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

# Register Targets (EC2 instances)
resource "aws_lb_target_group_attachment" "my_target_group_attachment" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.myec2.id   # Register the EC2 instance to the target group
  port             = 80                       # The port for HTTP traffic
}

# Register the Second EC2 Instance to the Target Group
resource "aws_lb_target_group_attachment" "my_target_group_attachment_b" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.myec2_b.id   # Register the second EC2 instance
  port             = 80                         # The port for HTTP traffic
}


# Configure the Elastic Load Balancer (ALB)
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_traffic.id]  # Attach the security group

  # Define subnets in multiple Availability Zones for cross-zone load balancing
    subnets = [
        aws_subnet.my_subnet_a.id, 
        aws_subnet.my_subnet_b.id
    ]


  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true  # Enable cross-zone load balancing

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
    target_group_arn = aws_lb_target_group.my_target_group.arn  # Forward traffic to the target group
  }
}


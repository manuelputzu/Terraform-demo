# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = var.vpc_id
}

resource "aws_route_table" "public_rt" {
    vpc_id = var.vpc_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
}

resource "aws_route_table_association" "public_assoc" {
    subnet_id = var.subnet
    route_table_id = aws_route_table.public_rt.id
}


# EC2 configuration
provider "aws" {
  region     = "eu-central-1"
  profile = var.profile-id
}

resource "aws_instance" "myec2" {
  ami = var.ami
  instance_type = var.instance_type

  user_data = <<-EOF
    #!/bin/bash
    # install httpd (Linux 2 version)
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
  EOF

  subnet_id = var.subnet
  associate_public_ip_address = true # public IP
  tags = {
    Name = "my-first-ec2"
  }

  vpc_security_group_ids = ["sg-0b7da58f2ec0524f6"] # Associate instance with security group
}


# Security Groups configuration
resource "aws_security_group" "allow_tls" {
    name        = "terraform-firewall"
    description = "Managed from terraform"
    vpc_id      = "vpc-066c24b90c635c774"
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 100 # Port Range 80 to 100
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv6" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

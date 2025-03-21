# AWS Profile Configuration
variable "profile_id" {
  description = "AWS profile for authentication"
  type        = string
}

# VPC and Subnet Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_a_cidr" {
  description = "CIDR block for subnet A"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_b_cidr" {
  description = "CIDR block for subnet B"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zones" {
  description = "List of availability zones for the subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

# AMI and EC2 Configuration
variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# Security Group Configuration
variable "my_ip" {
  description = "The IP address for SSH access"
  type        = string
}

variable "ssh_port" {
  description = "The SSH port"
  type        = number
  default     = 22
}

variable "vpn_ip" {
  description = "The VPN IP address for SSH access"
  type        = string
}

# Elastic Load Balancer Configuration
variable "elb_name" {
  description = "Name of the Elastic Load Balancer"
  type        = string
}

variable "target_group_name" {
  description = "The name of the target group for the Load Balancer"
  type        = string
}

# EC2 Instance Tags
variable "ec2_instance_tags" {
  description = "Tags for EC2 instances"
  type        = map(string)
  default     = {
    Name = "my-first-ec2"
  }
}
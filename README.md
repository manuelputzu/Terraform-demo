# Terraform AWS Setup Demo

This Terraform configuration sets up a basic AWS infrastructure with an EC2 instance, an Internet Gateway, a route table, and security group rules.

## Prerequisites
- **Terraform** installed ([Download](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** installed and configured with an IAM user ([Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html))
- **AWS credentials profile** set up (`~/.aws/credentials`)

## Resources Created

### 1. Internet Gateway
- Attaches an Internet Gateway to the specified VPC.
- Creates a public route table to allow internet access.

### 2. EC2 Instance
- Deploys an EC2 instance within the specified subnet.
- Assigns a public IP to the instance.
- Associates the instance with a security group.

### 3. Security Groups
- **Ingress Rules:**
  - Allow HTTP traffic (ports 80-100) from all sources.
  - Plan to allow HTTPS traffic (port 443) from all sources.
  - Allow SSH access (port 22) from all sources.
- **Egress Rules:**
  - Allow all outbound traffic.

## Variables
The following variables should be defined in a `terraform.tfvars` file or passed via CLI:
```hcl
vpc_id = "your-vpc-id"
subnet = "your-subnet-id"
profile-id = "your-aws-profile"
ami = "your-ami-id"
instance_type = "t2.micro"
```

## Usage
1. **Initialize Terraform**
   ```sh
   terraform init
   ```
2. **Plan the deployment**
   ```sh
   terraform plan
   ```
3. **Apply the configuration**
   ```sh
   terraform apply -auto-approve
   ```
4. **Destroy the infrastructure (if needed)**
   ```sh
   terraform destroy -auto-approve
   ```
   
## Backup Strategy

This project includes a custom Python script to create PostgreSQL database backups and upload them to Amazon S3 for secure, durable storage.

### 🧪 Running the Backup

To run the backup manually, execute the following command in your terminal:

```bash
PGPASSWORD='your_password' python3 backup/backup_to_s3.py


## Notes
- Ensure that the provided `vpc_id` and `subnet` exist within your AWS account.
- Modify the security group settings as needed for your use case.

## Video Explanation
Check out my YouTube video where I explain my thoughts on this Terraform setup:
[Watch Here](https://youtu.be/bX18diFLLx0)

## License
This project is licensed under the MIT License.


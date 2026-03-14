# AWS EC2 Virtual Machine with Custom VPC — Terraform Deployment Guide

Deployed and documented by **Osenat Alonge** | Senior DevOps Engineer | TOVADEL Academy

---

## What You Will Build

A fully automated AWS EC2 instance deployment inside a custom VPC with public and private subnets using pure Terraform. Nginx is auto-installed via user_data script and the site is accessible from the browser immediately after deployment.

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Route Table
    │
    ▼
Public Subnet (10.0.1.0/24)
    │
    ▼
EC2 Instance — Ubuntu + Nginx
    │
Security Group (SSH + HTTP)
```

---

## Architecture Overview

| Component | Service | Details |
|-----------|---------|---------|
| VPC | Custom VPC | 10.0.0.0/16 |
| Public Subnet | us-east-1a | 10.0.1.0/24 |
| Private Subnet | us-east-1b | 10.0.2.0/24 |
| Internet Gateway | IGW | Attached to VPC |
| Route Table | Public RT | Route 0.0.0.0/0 to IGW |
| Security Group | EC2 SG | SSH (22) + HTTP (80) |
| EC2 Instance | Ubuntu 20.04 | t2.micro with Nginx |

---

## Prerequisites

Before you start make sure you have the following installed and configured:

```bash
# Check AWS CLI
aws --version

# Verify credentials
aws sts get-caller-identity

# Check Terraform
terraform -v

# Check Git
git --version
```

---

## Project Structure

```
terraform-aws-vm/
├── main.tf        # Provider + VPC + Subnets + IGW + Route Table + Security Group
├── ec2.tf         # EC2 Instance + Outputs
└── .gitignore     # Protects sensitive files
```

---

## Step 1 — Create the Project Directory

```bash
mkdir terraform-aws-vm
cd terraform-aws-vm
```

---

## Step 2 — Create main.tf

This file contains the AWS provider, custom VPC, public and private subnets, Internet Gateway, route table and security group.

```bash
cat > main.tf << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "terraform-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "terraform-private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-igw"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "terraform-public-rt"
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "main" {
  name        = "terraform-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "terraform-sg"
  }
}
EOF
```

---

## Step 3 — Create ec2.tf

This file launches the EC2 instance with Nginx auto-installed via user_data script and all output values.

```bash
cat > ec2.tf << 'EOF'
# EC2 Instance
resource "aws_instance" "web_server" {
  ami                         = "ami-0261755bbcb8c4a84"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.main.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Deployed by Olusola Alonge - DMI Cohort-2</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "terraform-ec2"
  }
}

# Output Public IP
output "instance_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Public IP of the EC2 instance"
}

output "website_url" {
  value       = "http://${aws_instance.web_server.public_ip}"
  description = "Website URL"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.web_server.public_ip}"
  description = "SSH command to connect to the instance"
}
EOF
```

> **Note:** The AMI `ami-0261755bbcb8c4a84` is Ubuntu 20.04 in us-east-1. If you use a different region update the AMI ID accordingly:
> ```bash
> aws ec2 describe-images \
>   --owners 099720109477 \
>   --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" \
>   --query "Images[0].ImageId" \
>   --output text
> ```

---

## Step 4 — Create .gitignore

```bash
cat > .gitignore << 'EOF'
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.backup
*.tfstate.lock.info
tfplan
*.tfplan
crash.log
*.tfvars
*.tfvars.json

# Environment
.env
.env.local
*.pem
*.key

# OS
.DS_Store
*.log
EOF
```

---

## Step 5 — Run Terraform Pipeline

```bash
# Initialise
terraform init

# Validate
terraform validate

# Plan — review what will be created
terraform plan

# Apply
terraform apply
```

Type `yes` when prompted. Takes about 1-2 minutes.

---

## Step 6 — Get Outputs

```bash
terraform output
```

Expected output:
```
instance_public_ip = "x.x.x.x"
ssh_command        = "ssh -i ~/.ssh/id_rsa ubuntu@x.x.x.x"
website_url        = "http://x.x.x.x"
```

---

## Step 7 — Verify EC2 is Running

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=terraform-ec2" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}" \
  --output table
```

Expected output:
```
--------------------------------------------------
|            DescribeInstances                   |
+------------+-------------+--------------------+
|     ID     |    State    |        IP          |
+------------+-------------+--------------------+
|  i-xxxxx   |   running   |   x.x.x.x          |
+------------+-------------+--------------------+
```

---

## Step 8 — Visit the Website

Open in your browser:
```
http://<your-public-ip>
```

You should see:
```
Deployed by Olusola Alonge - DMI Cohort-2
```

---

## Step 9 — SSH Into the EC2 Instance

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<public-ip>
```

Once inside verify Nginx is running:
```bash
sudo systemctl status nginx
curl http://localhost
```

---

## Step 10 — Push to GitHub

```bash
git init
git add .
git status
git commit -m "AWS EC2 deployment with custom VPC using Terraform"
git remote add origin https://github.com/<your-username>/terraform-aws-vm.git
git branch -M main
git push -u origin main
```

---

## Step 11 — Destroy Resources

Always destroy after testing to avoid unnecessary AWS costs:

```bash
terraform destroy --auto-approve
```

Verify everything is deleted:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=terraform-ec2" \
  --query "Reservations[].Instances[].State.Name" \
  --output text
```

Should return `terminated`.

---

## Common Issues and Fixes

### Issue 1 — Variables Not Declared Error
```
Error: Reference to undeclared input variable
```

**Fix:** Make sure variables.tf exists if you are using `var.` references. In this project we use hardcoded values so no variables.tf is needed.

### Issue 2 — AMI Not Found in Region
The AMI ID is region-specific. `ami-0261755bbcb8c4a84` only works in us-east-1.

**Fix:** Find the correct AMI for your region:
```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" \
  --query "Images[0].ImageId" \
  --output text \
  --region <your-region>
```

### Issue 3 — Cannot SSH Into Instance
The key pair does not match or the security group blocks SSH.

**Fix:** Verify the security group allows port 22 and your key is correct:
```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=terraform-sg" \
  --query "SecurityGroups[].IpPermissions"
```

### Issue 4 — Website Not Loading
Nginx takes 1-2 minutes to start after instance launch via user_data.

**Fix:** Wait 2 minutes after apply completes then refresh the browser. Or SSH in and check:
```bash
sudo systemctl status nginx
sudo cat /var/log/cloud-init-output.log
```

### Issue 5 — Large Files Rejected by GitHub
The `.terraform` folder contains provider binaries over 100MB.

**Fix:**
```bash
git rm -r --cached .terraform/
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch .terraform/" \
  --prune-empty --tag-name-filter cat -- --all
git push origin main --force
```

### Issue 6 — Outputs Not Found After Apply
The outputs.tf was not created properly.

**Fix:**
```bash
terraform refresh
terraform output
```

---

## EC2 Instance Details

| Setting | Value |
|---------|-------|
| OS | Ubuntu 20.04 LTS |
| Instance Type | t2.micro |
| Region | us-east-1 |
| Availability Zone | us-east-1a |
| Public IP | Auto-assigned |
| Web Server | Nginx |

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| Terraform | Infrastructure as Code |
| AWS VPC | Custom network isolation |
| AWS EC2 | Virtual machine |
| AWS Internet Gateway | Internet access |
| AWS Security Group | Firewall rules |
| Ubuntu 20.04 | Operating system |
| Nginx | Web server |

---

## Author

**Osenat Alonge**
Senior DevOps Engineer | Founder of TOVADEL Academy

LinkedIn: linkedin.com/in/osenat-alonge-84379124b
GitHub: github.com/etaoko333
TOVADEL Academy: tovadelacademy.co.uk

---

## Acknowledgements

This project was completed as part of the DevOps Micro Internship (DMI) Cohort-2 organised by Pravin Mishra.

Join DMI free: https://lnkd.in/dzJGHptZ

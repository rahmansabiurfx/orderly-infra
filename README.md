# Multi-Tier AWS Infrastructure as Code

Production-grade, highly available, multi-tier AWS infrastructure
provisioned entirely through Terraform.


## Architecture

- **Networking**: VPC with public, private, and database subnets across 2 AZs
- **Compute**: Application Load Balancer + EC2 Auto Scaling Group
- **Database**: RDS PostgreSQL with Multi-AZ (prod) / Single-AZ (dev)
- **Security**: Chained security groups enforcing tier isolation


## Project Structure

├── modules/ # Reusable Terraform modules
│ ├── networking/ # VPC, subnets, gateways, route tables
│ ├── security/ # Security groups with tier chaining
│ ├── compute/ # ALB + EC2 Auto Scaling Group
│ └── database/ # RDS PostgreSQL
├── environments/ # Environment-specific configurations
│ ├── dev/ # Development (small, cost-optimized)
│ └── prod/ # Production (HA, multi-AZ)
└── remote-state/ # Terraform state backend (S3 + DynamoDB)


## Prerequisites

- Terraform >= 1.7
- AWS CLI v2 configured with appropriate credentials
- AWS account with billing alerts configured


## Deployment

See phase-by-phase instructions in the docs/ folder.


## Cost Warning

This infrastructure incurs AWS charges. Primary costs:
- NAT Gateway: ~\$32/month
- ALB: ~\$16/month  
- RDS: Variable by instance size
- EC2: Variable by instance type and count

**Always run `terraform destroy` when not actively using the infrastructure.**


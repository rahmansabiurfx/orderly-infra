<div align="center">

# 🏗️ Multi-Tier AWS Infrastructure as Code

**Production-grade, highly available, multi-tier AWS infrastructure provisioned entirely through Terraform.**

Designed to demonstrate real-world infrastructure engineering — modular design, multi-environment support, defense-in-depth security, and cost-aware architecture decisions.

[![Architecture: Three-Tier](https://img.shields.io/badge/Architecture-Three--Tier-0052CC?style=for-the-badge)](.)
[![IaC: Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Cloud: AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com/)

</div>

---

## 📐 Architecture

```
                    ┌─────────────────────────────────┐
                    │           INTERNET              │
                    └───────────────┬─────────────────┘
                                    │
                    ┌───────────────▼─────────────────┐
                    │     Application Load Balancer   │
                    │         (Public Subnets)        │
                    │     ┌──────────┬──────────┐     │
                    │     │  AZ-1a   │  AZ-1b   │     │
                    │     └──────────┴──────────┘     │
                    └───────────────┬─────────────────┘
                                    │ Port 8080 (SG-chained)
                    ┌───────────────▼─────────────────┐
                    │    EC2 Auto Scaling Group       │
                    │       (Private Subnets)         │
                    │     ┌──────────┬──────────┐     │
                    │     │  AZ-1a   │  AZ-1b   │     │
                    │     │ min:1-2  │ max:2-4  │     │
                    │     └──────────┴──────────┘     │
                    └───────────────┬─────────────────┘
                                    │ Port 5432 (SG-chained)
                    ┌───────────────▼─────────────────┐
                    │      RDS PostgreSQL 15          │
                    │       (Database Subnets)        │
                    │     ┌──────────┬──────────┐     │
                    │     │ Primary  │ Standby  │     │
                    │     │ (AZ-1a)  │ (AZ-1b)  │     │
                    │     └──────────┴──────────┘     │
                    └─────────────────────────────────┘
```
### [👤]🔑 Credentials Management
```
Terraform → random_password (32 chars, cryptographically secure)

→ AWS Secrets Manager (encrypted at rest with KMS)

→ RDS instance (password set during creation)

→ EC2 IAM policy (least-privilege read access to secret)

Applications retrieve database credentials at runtime via the AWS SDK,
never from environment variables or configuration files.
```

### 🌐 Network Design

> **VPC CIDR:** `10.0.0.0/16` (dev) | `10.1.0.0/16` (prod)

```
                AZ-1a                       AZ-1b
          ┌───────────────┐           ┌───────────────┐
 Public:  │ 10.x.1.0/24   │           │ 10.x.2.0/24   │  ← ALB, NAT Gateway
          └───────────────┘           └───────────────┘
          ┌───────────────┐           ┌───────────────┐
 Private: │ 10.x.11.0/24  │           │ 10.x.12.0/24  │  ← App Servers (EC2)
          └───────────────┘           └───────────────┘
          ┌───────────────┐           ┌───────────────┐
 Database:│ 10.x.21.0/24  │           │ 10.x.22.0/24  │  ← RDS PostgreSQL
          └───────────────┘           └───────────────┘
```

| Subnet Tier | Routing |
|---|---|
| **Public** | Internet Gateway — bidirectional internet access |
| **Private** | NAT Gateway — outbound-only internet access |
| **Database** | No internet route — VPC-internal only |

---

### 🔒 Security — Defense in Depth

Traffic is restricted at every tier using **security group chaining** — each security group references the one above it, not CIDR blocks:

```
Internet (0.0.0.0/0)
        │
        │  Ports 80, 443
        ▼
  ┌──────────┐
  │  ALB SG  │  Inbound: HTTP/HTTPS from internet
  └────┬─────┘  Outbound: Port 8080 to App SG only
       │
       │  Port 8080, source = ALB SG
       ▼
  ┌──────────┐
  │  App SG  │  Inbound: Port 8080 from ALB SG only
  └────┬─────┘  Outbound: Port 5432 to DB SG, 80/443/53 to internet
       │
       │  Port 5432, source = App SG
       ▼
  ┌──────────┐
  │  DB SG   │  Inbound: Port 5432 from App SG only
  └──────────┘  Outbound: None (stateful responses only)
```

> [!IMPORTANT]
> - ✅ The internet can **only** reach the ALB
> - ✅ Only the ALB can reach the app servers
> - ✅ Only the app servers can reach the database
> - ✅ The database **cannot** initiate any outbound connections

---

## 📁 Project Structure

```
project-1-aws-infrastructure/
│
├── modules/                        # Reusable Terraform modules
│   ├── networking/                 # VPC, subnets, IGW, NAT, route tables
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/                   # Chained security groups (ALB → App → DB)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/                    # ALB, ASG, Launch Template, IAM
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── user_data.sh
│   └── database/                   # RDS PostgreSQL
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/                   # Environment-specific configurations
│   ├── dev/                        # Development (cost-optimized)
│   │   ├── main.tf                 # Wires all modules with dev parameters
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf              # S3 remote state (key: dev/)
│   │   └── example.tfvars          # Example variable values
│   └── prod/                       # Production (high availability)
│       ├── main.tf                 # Wires all modules with prod parameters
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.tf              # S3 remote state (key: prod/)
│       └── example.tfvars
│
├── remote-state/                   # Bootstrap: S3 bucket + DynamoDB for state
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── .gitignore
└── README.md
```

### 🔗 Module Dependency Chain

```
environments/dev/main.tf (or prod)
  │
  ├── module "networking"   → VPC, subnets, gateways, route tables
  │   │
  │   ├── outputs: vpc_id, subnet_ids, db_subnet_group_name
  │   ▼
  ├── module "security"     → Security groups + chained rules
  │   │
  │   ├── inputs:  vpc_id (from networking)
  │   ├── outputs: alb_sg_id, app_sg_id, db_sg_id
  │   ▼
  ├── module "compute"      → ALB, target group, ASG, scaling policy
  │   │
  │   ├── inputs:  subnet_ids (networking), sg_ids (security)
  │   ├── outputs: alb_dns_name
  │   ▼
  └── module "database"     → RDS PostgreSQL
      │
      ├── inputs:  db_subnet_group (networking), db_sg_id (security)
      └── outputs: db_endpoint
```

---

## ⚖️ Environment Comparison

| Parameter | Dev | Prod |
|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` |
| NAT Gateways | 1 (single, shared) | 2 (one per AZ) |
| EC2 Instance Type | `t3.micro` | `t3.small` |
| ASG Min / Max | 1 / 2 | 2 / 4 |
| RDS Instance Class | `db.t3.micro` | `db.t3.small` |
| RDS Multi-AZ | ❌ No (single AZ) | ✅ Yes (automatic failover) |
| Backup Retention | 1 day | 7 days |
| Deletion Protection | Disabled | Enabled |
| Final Snapshot on Delete | Skipped | Required |
| Estimated Monthly Cost | ~\$50–70 | ~\$130–170 |

---

## 🛠️ Tech Stack

| Category | Tools |
|---|---|
| **Infrastructure as Code** | Terraform >= 1.7 (modules, remote state, workspaces) |
| **Cloud Provider** | AWS (VPC, EC2, ALB, ASG, RDS, S3, DynamoDB, IAM) |
| **Operating System** | Amazon Linux 2023 (EC2 instances) |
| **Application** | Python Flask (simple API for infrastructure validation) |
| **State Management** | S3 (encrypted, versioned) + DynamoDB (locking) |
| **Version Control** | Git + GitHub |
| **Secrets Management** | AWS Secrets Manager (auto-generated credentials, KMS encryption) |

---

## ✅ Prerequisites

- **Terraform** >= 1.7 — [Install Guide](https://developer.hashicorp.com/terraform/downloads)
- **AWS CLI** v2 — [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **AWS Account** with IAM user credentials configured (`aws configure`)
- **Git**

---

## 🚀 Deployment

### Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/project-1-aws-infrastructure.git
cd project-1-aws-infrastructure
```

### Step 2: Deploy Remote State Backend (One-Time Setup)

```bash
cd remote-state

# Create terraform.tfvars with your values:
cat > terraform.tfvars << 'EOF'
aws_region          = "us-east-1"
project_name        = "multitier-infra"
state_bucket_name   = "YOUR-GLOBALLY-UNIQUE-BUCKET-NAME"
dynamodb_table_name = "YOUR-LOCK-TABLE-NAME"
EOF

terraform init
terraform plan
terraform apply
```

> Save the output values — you'll need them for the environment backend configurations.

### Step 3: Deploy Dev Environment

```bash
cd ../environments/dev

# Update backend.tf with your S3 bucket name, DynamoDB table name, and region

# Create terraform.tfvars from the example and fill in values:
cp example.tfvars terraform.tfvars
# Edit terraform.tfvars (especially db_password)

terraform init
terraform plan
terraform apply
```

> ⏳ Wait 5–10 minutes for all resources (especially RDS) to provision.

### Step 4: Access the Application

```bash
# Get the ALB URL
terraform output application_url

# Test the endpoints
curl $(terraform output -raw application_url)/
curl $(terraform output -raw application_url)/health
```

<details>
<summary>📄 Expected response from <code>/</code></summary>

```json
{
  "status": "running",
  "app": "multitier-infra",
  "environment": "dev",
  "instance": {
    "id": "i-0abc123def456",
    "az": "us-east-1a",
    "private_ip": "10.0.11.50",
    "hostname": "ip-10-0-11-50.ec2.internal"
  },
  "timestamp": "2024-01-15T10:30:45Z"
}
```

</details>

### Step 5: Deploy Prod Environment *(Optional)*

```bash
cd ../prod

# Same process: configure backend.tf, create terraform.tfvars, init, apply
terraform init
terraform plan
terraform apply
```

### Step 6: Destroy (Cost Saving)

```bash
# Always destroy when not actively using the infrastructure
cd environments/dev
terraform destroy

# For prod (if deployed):
cd ../prod
# First disable deletion protection on RDS via AWS console or:
# Update main.tf: deletion_protection = false → terraform apply → then:
terraform destroy
```

---

## 🧠 Design Decisions

<details>
<summary><strong>Why Security Group Chaining Instead of CIDR Rules?</strong></summary>

SG-based rules reference the security group ID of the source/destination instead of IP ranges. If an instance's IP changes (ASG scaling, replacement), rules still work. It's self-documenting — *"App SG allows traffic from ALB SG"* is clearer than *"App SG allows traffic from 10.0.1.0/24."* It enforces tier boundaries regardless of subnet configuration.

</details>

<details>
<summary><strong>Why Separate <code>aws_security_group_rule</code> Resources?</strong></summary>

Inline `ingress`/`egress` blocks cause circular dependency errors when two security groups reference each other (ALB SG → App SG and App SG → ALB SG). Separate rule resources let Terraform create both SGs first (as empty shells), then create the cross-referencing rules.

</details>

<details>
<summary><strong>Why <code>count</code> Instead of <code>for_each</code> for Subnets?</strong></summary>

Subnets are ordered (AZ-1 gets CIDR index 0, AZ-2 gets index 1). `count` with index-based access is simpler and sufficient. `for_each` is better when resources are identified by a key (like a map of configurations) rather than position. For 2 AZs with matching lists, `count` is the cleaner choice.

</details>

<details>
<summary><strong>Why Single NAT Gateway in Dev?</strong></summary>

NAT Gateways cost ~\$32/month each. Dev uses a single NAT to cut costs. The trade-off: if the NAT's AZ fails, private subnets in the other AZ lose outbound internet. Acceptable for dev — not for prod, which gets one NAT per AZ.

</details>

<details>
<summary><strong>Why <code>ignore_changes = [desired_capacity]</code> on the ASG?</strong></summary>

Auto scaling dynamically changes `desired_capacity` based on load. Without `ignore_changes`, every `terraform apply` would reset it to the hardcoded value, fighting the auto scaler and potentially killing instances during traffic spikes.

</details>

<details>
<summary><strong>Why IMDSv2 (Token-Based) for Instance Metadata?</strong></summary>

IMDSv1 allowed simple GET requests to the metadata endpoint (`169.254.169.254`), making it vulnerable to SSRF (Server-Side Request Forgery) attacks — notably exploited in the 2019 Capital One breach. IMDSv2 requires a token obtained via PUT request first, preventing most SSRF vectors.

</details>

<details>
<summary><strong>Why No Outbound Rules on the Database Security Group?</strong></summary>

Security groups are stateful — response traffic to allowed inbound connections passes automatically. The database never initiates outbound connections; it only responds to queries from app servers. Zero explicit outbound rules means a compromised database can't be used to scan the network or exfiltrate data.

</details>

<details>
<summary><strong>Why <code>gp3</code> Storage for RDS?</strong></summary>

`gp3` is the latest generation general-purpose SSD. It delivers 3,000 IOPS baseline (free) at \$0.08/GB/month — better performance and lower cost than the older `gp2`. No reason to use `gp2` for new deployments.

</details>

### Why AWS Secrets Manager Instead of Hardcoded Passwords?

Database credentials follow a secure lifecycle:

1. **Generation**: Terraform's `random_password` generates a 32-character cryptographically secure password with mixed case, numbers, and special characters
2. **Storage**: The password is stored in AWS Secrets Manager, encrypted at rest using AWS KMS, never written to disk or Git
3. **Access**: EC2 instances have an IAM policy granting `secretsmanager:GetSecretValue` for only the specific secret ARN (least privilege)
4. **Format**: The secret contains complete connection information (username, password, host, port, dbname, connection string) following the [AWS RDS secret JSON structure](https://docs.aws.amazon.com/secretsmanager/latest/userguide/reference_secret_json_structure.html)

This eliminates:
- Plaintext passwords in `terraform.tfvars` files
- Passwords in shell history (`-var="db_password=..."`)
- Risk of accidentally committing credentials to Git
- Need for manual password management
---

## 💰 Cost Estimate

| Resource | Dev (Monthly) | Prod (Monthly) |
|---|---|---|
| NAT Gateway | ~\$32 (×1) | ~\$64 (×2) |
| ALB | ~\$16 | ~\$16 |
| EC2 (t3.micro / t3.small) | ~\$7.50 (×1) | ~\$30 (×2) |
| RDS (db.t3.micro / db.t3.small) | ~\$13 (single-AZ) | ~\$52 (Multi-AZ) |
| EBS Storage | ~\$2 | ~\$4 |
| Data Transfer | ~\$1–5 | ~\$1–5 |
| **Total** | **~\$50–70** | **~\$130–170** |

> [!WARNING]
> **Always run `terraform destroy` when not actively using the infrastructure.**
> A few hours of testing costs < \$1. Leaving it running for a month costs \$50–170.

---

## 🔍 Verification Commands

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=multitier-infra" \
  --query "Vpcs[].{ID:VpcId,CIDR:CidrBlock}" --output table

# Check subnets
aws ec2 describe-subnets \
  --filters "Name=tag:Project,Values=multitier-infra" \
  --query "Subnets[].{Name:Tags[?Key=='Name']|[0].Value,AZ:AvailabilityZone,CIDR:CidrBlock}" \
  --output table

# Check ALB
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'multitier-infra')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
  --output table

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=multitier-infra" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,AZ:Placement.AvailabilityZone,State:State.Name}" \
  --output table

# Check RDS
aws rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier,'multitier-infra')].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,MultiAZ:MultiAZ,Class:DBInstanceClass}" \
  --output table

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --query "TargetGroups[?contains(TargetGroupName,'multitier-infra')].TargetGroupArn" \
    --output text) \
  --query "TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State}" \
  --output table
```

---

## 📚 What I Learned

- **VPC networking** — Subnet tiers, CIDR design, route table logic, NAT vs IGW
- **Terraform modules** — Encapsulation, input/output chaining, DRY infrastructure code
- **Security group design** — SG chaining, stateful firewall behavior, defense in depth
- **State management** — Remote state in S3, DynamoDB locking, the bootstrap problem
- **Auto scaling** — Launch templates, target tracking policies, health check integration
- **RDS operations** — Multi-AZ failover, encryption at rest, automated backups, storage autoscaling
- **Cost engineering** — Dev vs prod trade-offs, NAT Gateway cost awareness, right-sizing
- **Operational practices** — Tagging strategy, IMDSv2 enforcement, deletion protection

---

## 🔮 Future Improvements

- [ ] Add HTTPS listener with ACM certificate on the ALB
- [ ] ~~Integrate AWS Secrets Manager for database credentials~~ ✅ 
- [ ] Add CloudWatch alarms for ASG, ALB 5xx rates, and RDS metrics
- [ ] Implement VPC Flow Logs for network traffic auditing
- [ ] Add a bastion host or SSM-only access for database administration
- [ ] Create a CI pipeline to run `terraform validate` and `terraform plan` on PRs
- [ ] Add `tflint` and `checkov` for static analysis and security scanning

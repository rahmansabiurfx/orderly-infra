# environments/prod/example.tfvars

aws_region   = "us-east-1"
project_name = "multitier-infra"
environment  = "prod"

vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24"]
database_subnet_cidrs = ["10.1.21.0/24", "10.1.22.0/24"]

instance_type        = "t3.small"
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

db_instance_class = "db.t3.small"
db_name           = "appdb"
db_username       = "dbadmin"
db_password       = "CHANGE_ME_use_a_strong_password"

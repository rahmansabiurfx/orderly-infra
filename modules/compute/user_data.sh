#!/bin/bash
# ─────────────────────────────────────────────────────────────
# EC2 Instance Bootstrap Script (User Data)
#
# Runs ONCE on first boot. Sets up:
#   1. System updates
#   2. Python + Flask + boto3 (AWS SDK)
#   3. Web application with:
#      - Instance metadata endpoints (load balancing verification)
#      - Health check endpoint (ALB integration)
#      - Database credential retrieval from Secrets Manager
#   4. systemd service for auto-start and crash recovery
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# Log all output for debugging
exec > >(tee /var/log/user-data.log) 2>&1
echo "========================================="
echo "User Data Script Started: $(date)"
echo "========================================="

# ─── System Updates ────────────────────────────────────────
echo ">>> Installing system updates..."
dnf update -y

# ─── Install Python ────────────────────────────────────────
echo ">>> Installing Python and pip..."
dnf install -y python3 python3-pip

# ─── Create Application User ──────────────────────────────
echo ">>> Creating application user..."
useradd --system --shell /sbin/nologin --no-create-home appuser || true

# ─── Create Application Directory ─────────────────────────
echo ">>> Setting up application..."
mkdir -p /opt/app

# ─── Write Application Code ───────────────────────────────
cat > /opt/app/app.py << 'PYEOF'
"""
Flask application for infrastructure validation.

Endpoints:
  GET /         → App info + instance metadata (verify load balancing)
  GET /health   → Health check for ALB target group
  GET /db-check → Reads DB credentials from Secrets Manager (proves
                  the full chain: IAM role → Secrets Manager → credentials)

The /db-check endpoint demonstrates:
  1. EC2 instance has the correct IAM role attached
  2. IAM policy grants secretsmanager:GetSecretValue permission
  3. The secret exists and contains valid JSON
  4. The application can retrieve connection details at runtime
  
  In a production app, you'd use these credentials to create
  a database connection pool at startup instead of exposing
  them via an endpoint.
"""

import os
import json
import socket
import datetime
import subprocess

from flask import Flask, jsonify

app = Flask(__name__)

# ─── Configuration ─────────────────────────────────────────

AWS_REGION    = os.environ.get("AWS_REGION", "us-east-1")
DB_SECRET_ARN = os.environ.get("DB_SECRET_ARN", "")


# ─── Helper Functions ──────────────────────────────────────

def get_metadata(field):
    """Fetch EC2 instance metadata using IMDSv2 (token-based)."""
    try:
        token = subprocess.check_output([
            "curl", "-s", "-f",
            "-X", "PUT",
            "http://169.254.169.254/latest/api/token",
            "-H", "X-aws-ec2-metadata-token-ttl-seconds: 60"
        ], timeout=2).decode().strip()

        result = subprocess.check_output([
            "curl", "-s", "-f",
            "-H", f"X-aws-ec2-metadata-token: {token}",
            f"http://169.254.169.254/latest/meta-data/{field}"
        ], timeout=2).decode().strip()

        return result
    except Exception:
        return "unavailable"


def get_db_secret():
    """Retrieve database credentials from AWS Secrets Manager.
    
    Uses boto3 (AWS SDK for Python) with the IAM role attached
    to this EC2 instance. No hardcoded credentials needed —
    boto3 automatically uses the instance profile's temporary
    credentials.
    
    Returns:
        dict: Parsed secret containing username, host, port, dbname
              (password is masked for safety in the response)
        None: If retrieval fails
    """
    if not DB_SECRET_ARN:
        return None
    
    try:
        import boto3
        
        # boto3 automatically uses the IAM instance profile credentials.
        # These are temporary credentials that AWS rotates every ~6 hours.
        # No access keys needed — this is the secure way.
        client = boto3.client("secretsmanager", region_name=AWS_REGION)
        
        response = client.get_secret_value(SecretId=DB_SECRET_ARN)
        secret = json.loads(response["SecretString"])
        
        # Return the secret but MASK the password and connection string.
        # Never expose actual passwords via API endpoints.
        # In production, you'd use these credentials to create a
        # database connection pool, not return them in an HTTP response.
        return {
            "username": secret.get("username"),
            "password": "****" + secret.get("password", "")[-4:],
            "engine": secret.get("engine"),
            "host": secret.get("host"),
            "port": secret.get("port"),
            "dbname": secret.get("dbname"),
            "connection_string": "postgresql://{}:****@{}:{}/{}".format(
                secret.get("username"),
                secret.get("host"),
                secret.get("port"),
                secret.get("dbname")
            )
        }
    except ImportError:
        return {"error": "boto3 not installed"}
    except Exception as e:
        return {"error": str(e)}


# Fetch metadata once at startup
INSTANCE_ID       = get_metadata("instance-id")
AVAILABILITY_ZONE = get_metadata("placement/availability-zone")
PRIVATE_IP        = get_metadata("local-ipv4")


# ─── Endpoints ─────────────────────────────────────────────

@app.route("/")
def home():
    """Main endpoint — returns instance info for load balancing verification."""
    return jsonify({
        "status": "running",
        "app": os.environ.get("APP_NAME", "multi-tier-app"),
        "environment": os.environ.get("APP_ENV", "unknown"),
        "instance": {
            "id": INSTANCE_ID,
            "az": AVAILABILITY_ZONE,
            "private_ip": PRIVATE_IP,
            "hostname": socket.gethostname()
        },
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    })


@app.route("/health")
def health():
    """Health check endpoint for ALB target group."""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    }), 200


@app.route("/db-check")
def db_check():
    """Database credential check — proves the Secrets Manager integration.
    
    This endpoint:
      1. Uses boto3 with the EC2 instance's IAM role
      2. Calls secretsmanager:GetSecretValue
      3. Parses the JSON secret
      4. Returns masked credentials (password hidden)
    
    If this returns credentials, it proves:
      - IAM instance profile is correctly attached
      - IAM policy grants secretsmanager:GetSecretValue
      - Secret exists in Secrets Manager
      - Secret contains valid JSON with connection details
    
    If this returns an error, check:
      - IAM policy resource ARN matches the secret ARN
      - Secret name/ARN is correctly passed via environment variable
      - boto3 is installed
    """
    secret = get_db_secret()
    
    if secret is None:
        return jsonify({
            "status": "not_configured",
            "message": "DB_SECRET_ARN environment variable not set",
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
        }), 200
    
    if "error" in secret:
        return jsonify({
            "status": "error",
            "message": secret["error"],
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
        }), 500
    
    return jsonify({
        "status": "ok",
        "message": "Successfully retrieved database credentials from Secrets Manager",
        "credentials": secret,
        "secret_arn": DB_SECRET_ARN,
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    }), 200


if __name__ == "__main__":
    port = int(os.environ.get("APP_PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
PYEOF

# ─── Install Python Dependencies ──────────────────────────
echo ">>> Installing Flask and boto3..."
pip3 install flask boto3

# ─── Set Ownership ─────────────────────────────────────────
chown -R appuser:appuser /opt/app

# ─── Create systemd Service ───────────────────────────────
echo ">>> Creating systemd service..."
cat > /etc/systemd/system/webapp.service << SVCEOF
[Unit]
Description=Multi-Tier Web Application
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/app
Environment=APP_PORT=${app_port}
Environment=APP_ENV=${environment}
Environment=APP_NAME=${project_name}
Environment=DB_SECRET_ARN=${db_secret_arn}
Environment=AWS_REGION=${aws_region}
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# ─── Start the Service ────────────────────────────────────
echo ">>> Starting application..."
systemctl daemon-reload
systemctl enable webapp.service
systemctl start webapp.service

echo "========================================="
echo "User Data Script Complete: $(date)"
echo "========================================="

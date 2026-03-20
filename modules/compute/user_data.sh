#!/bin/bash
# ─────────────────────────────────────────────────────────────
# EC2 Instance Bootstrap Script (User Data)
#
# Runs ONCE on first boot. Sets up:
#   1. System updates
#   2. Python + Flask web application
#   3. systemd service for auto-start and crash recovery

set -euo pipefail

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
Simple Flask app for infrastructure validation.

Endpoints:
  GET /        → App info + instance metadata (verify load balancing)
  GET /health  → Health check for ALB target group
"""

import os
import socket
import datetime
import subprocess

from flask import Flask, jsonify

app = Flask(__name__)


def get_metadata(field):
    """Fetch EC2 instance metadata using IMDSv2 (token-based).
   
    IMDSv2 is the secure way to get instance metadata.
    It requires a token obtained via PUT request first,
    then uses that token for the actual metadata request.
    This prevents SSRF attacks from accessing metadata.
    """
    try:
        # Step 1: Get a token (valid for 60 seconds)
        token = subprocess.check_output([
            "curl", "-s", "-f",
            "-X", "PUT",
            "http://169.254.169.254/latest/api/token",
            "-H", "X-aws-ec2-metadata-token-ttl-seconds: 60"
        ], timeout=2).decode().strip()

        # Step 2: Use token to fetch metadata
        result = subprocess.check_output([
            "curl", "-s", "-f",
            "-H", f"X-aws-ec2-metadata-token: {token}",
            f"http://169.254.169.254/latest/meta-data/{field}"
        ], timeout=2).decode().strip()

        return result
    except Exception:
        return "unavailable"

# Fetch metadata once at startup (doesn't change during instance lifetime)
INSTANCE_ID = get_metadata("instance-id")
AVAILABILITY_ZONE = get_metadata("placement/availability-zone")
PRIVATE_IP = get_metadata("local-ipv4")


@app.route("/")
def home():
    """Main endpoint - returns instance info.
    
    When you hit this through the ALB multiple times,
    you'll see different instance IDs and AZs — proving
    the load balancer is distributing traffic.
    """
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
    """Health check endpoint for ALB.
    
    The ALB hits this every 30 seconds. If it returns 200,
    the instance is healthy. If it returns anything else
    (or times out), the instance is marked unhealthy.
    
    In a real app, you might check database connectivity,
    disk space, memory usage, etc. here.
    """
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    }), 200


if __name__ == "__main__":
    port = int(os.environ.get("APP_PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
PYEOF


# ─── Install Python Dependencies ──────────────────────────

echo ">>> Installing Flask..."
pip3 install flask


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
USERDATA

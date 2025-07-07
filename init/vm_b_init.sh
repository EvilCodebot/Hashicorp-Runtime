#!/bin/bash

# Install and enable Docker
dnf install -y docker
systemctl start docker
systemctl enable docker

# Setup app dirs
mkdir -p /opt/app/certs

# Get S3 bucket name
BUCKET_PREFIX="hashicorp-runtime-files-"
BUCKET_NAME=$(aws s3 ls | grep ${BUCKET_PREFIX} | awk '{print $3}')

# Get app files from S3
aws s3 cp s3://${BUCKET_NAME}/main.go /opt/app/
aws s3 cp s3://${BUCKET_NAME}/Dockerfile /opt/app/
aws s3 cp s3://${BUCKET_NAME}/go.mod /opt/app/

# Get TLS certs from SSM
aws ssm get-parameter --name "/tls/ca/certificate" --with-decryption --query "Parameter.Value" --output text > /opt/app/certs/ca.crt
aws ssm get-parameter --name "/tls/vm-b/certificate" --with-decryption --query "Parameter.Value" --output text > /opt/app/certs/vm-b.crt
aws ssm get-parameter --name "/tls/vm-b/private-key" --with-decryption --query "Parameter.Value" --output text > /opt/app/certs/vm-b.key

# Set cert permissions
chmod 600 /opt/app/certs/vm-b.key
chmod 644 /opt/app/certs/*.crt

# Build and run container
cd /opt/app
docker build -t go-app .
docker run -d \
    --name go-app \
    -p 443:443 \
    -v /opt/app/certs:/app/certs:ro \
    -e LISTEN_PORT=443 \
    -e TLS_CERT=/app/certs/vm-b.crt \
    -e TLS_KEY=/app/certs/vm-b.key \
    -e TLS_CA=/app/certs/ca.crt \
    --restart always \
    go-app 
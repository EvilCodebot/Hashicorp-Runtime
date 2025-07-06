#!/bin/bash

# Install Docker
dnf install -y docker
systemctl start docker
systemctl enable docker

# Create directory for Nginx configuration
mkdir -p /opt/nginx

# Get bucket name using the known prefix
BUCKET_PREFIX="hashicorp-runtime-files-"
BUCKET_NAME=$(aws s3 ls | grep ${BUCKET_PREFIX} | awk '{print $3}')

# Download configuration files from S3
aws s3 cp s3://${BUCKET_NAME}/docker-compose.yml /opt/nginx/
aws s3 cp s3://${BUCKET_NAME}/nginx.conf /opt/nginx/

# Get VM B's private IP using its Name tag
VM_B_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=VM-B" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PrivateIpAddress" \
    --output text)

# Update nginx.conf with VM B's private IP
sed -i "s/VM_B_IP/${VM_B_IP}/g" /opt/nginx/nginx.conf

# Start Nginx container using Docker
docker run -d \
  --name nginx \
  --restart always \
  -v /opt/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  -p 10000:10000 \
  nginx:alpine

# Start Nginx container using Docker Compose
# cd /opt/nginx
#docker compose up -d

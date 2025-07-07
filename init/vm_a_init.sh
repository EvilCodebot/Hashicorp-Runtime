#!/bin/bash

# Install and enable Docker
dnf install -y docker make
systemctl start docker
systemctl enable docker

# Setup Nginx dirs
mkdir -p /opt/nginx/certs

# Set default path for all users
echo 'export PATH=/opt/nginx:$PATH' | sudo tee /etc/profile.d/default_path.sh
sudo chmod +x /etc/profile.d/default_path.sh
source /etc/profile.d/default_path.sh

# Get S3 bucket name
BUCKET_PREFIX="hashicorp-runtime-files-"
BUCKET_NAME=$(aws s3 ls | grep ${BUCKET_PREFIX} | awk '{print $3}')

# Get Nginx config from S3
aws s3 cp s3://${BUCKET_NAME}/nginx.conf /opt/nginx/

# Get Makefile from S3
aws s3 cp s3://${BUCKET_NAME}/Makefile /opt/nginx/

# Set up Makefile permissions and working directory
chmod +x /opt/nginx/Makefile

# Get VM-B private IP and update nginx.conf
VM_B_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=VM-B" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PrivateIpAddress" \
    --output text)
sed -i "s/VM_B_IP/${VM_B_IP}/g" /opt/nginx/nginx.conf

# Get TLS certs from SSM
aws ssm get-parameter --name "/tls/ca/certificate" --with-decryption --query "Parameter.Value" --output text > /opt/nginx/certs/ca.crt
aws ssm get-parameter --name "/tls/vm-a/certificate" --with-decryption --query "Parameter.Value" --output text > /opt/nginx/certs/vm-a.crt
aws ssm get-parameter --name "/tls/vm-a/private-key" --with-decryption --query "Parameter.Value" --output text > /opt/nginx/certs/vm-a.key

# Set cert permissions
chmod 600 /opt/nginx/certs/vm-a.key
chmod 644 /opt/nginx/certs/*.crt

# Run Nginx container
docker run -d \
  --name nginx \
  --restart always \
  -v /opt/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /opt/nginx/certs:/etc/nginx/certs:ro \
  -p 10000:10000 \
  -p 10443:10443 \
  nginx:alpine


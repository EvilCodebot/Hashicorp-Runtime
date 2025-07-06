#!/bin/bash

# Install Docker
dnf install -y docker
systemctl start docker
systemctl enable docker

# Create app directory
mkdir -p /opt/app

# Get bucket name using the known prefix
BUCKET_PREFIX="hashicorp-runtime-files-"
BUCKET_NAME=$(aws s3 ls | grep ${BUCKET_PREFIX} | awk '{print $3}')

# Download application files from S3
aws s3 cp s3://${BUCKET_NAME}/main.go /opt/app/
aws s3 cp s3://${BUCKET_NAME}/Dockerfile /opt/app/
aws s3 cp s3://${BUCKET_NAME}/go.mod /opt/app/

# Build and run the container
cd /opt/app
docker build -t go-app .
docker run -d \
    --name go-app \
    -p 8080:8080 \
    -e LISTEN_PORT=8080 \
    --restart always \
    go-app 
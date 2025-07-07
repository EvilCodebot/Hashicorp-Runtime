# Hashicorp-Runtime

IaC to provision AWS infrastructure with NGINX (Docker, VM A) as a reverse proxy to a Go HTTP server (Docker, VM B) over mTLS in a private subnet.

## Architecture Overview

This project sets up two AWS EC2 instances in a secure VPC configuration:

- **VM A**: Runs an Nginx reverse proxy in a Docker container
- **VM B**: Hosts a Go HTTP server in a Docker container
- Containers communicate securely through mTLS in a private subnet

## Key Features

1. **Secure mTLS Communication**
   - Custom Certificate Authority (CA) for certificate signing
   - Nginx proxy accepts both Non-TLS and TLS traffic then establishes a mTLS connection with the Go server

2. **Network Security**
   - Private subnet configuration with no direct internet access
   - NAT Gateway for controlled outbound access (For pulling dependencies: golang:1.22-alpine, nginx:alpine etc)
   - VPC endpoints for AWS services

3. **Secure Storage & Management**
   - SSM Parameter Store for certificate management
   - S3 bucket for application files
   - IAM roles and policies for least-privilege access

## Prerequisites

- AWS CLI configured with appropriate credentials
- AWS session-manager-plugin
- Terraform
- Make

## Getting Started

To understand how everything works, start with vm_b_init.sh and vm_a_init.sh—these run on the first startup of each VM. Alternatively, explore the Makefile to get started.


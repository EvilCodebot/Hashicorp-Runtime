terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2" # Changed to Sydney region
}

# Get latest Amazon Linux 2023 with kernel 6.1
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main IGW"
  }
}

# Public subnet - for NAT Gateway
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-southeast-2a"

  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet for NAT"
  }
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "Main NAT Gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

# Security group for private instances - internal traffic only
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.main.id

  # Allow all traffic between instances in the private subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]  # Private subnet CIDR
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Private subnet - where your workload runs
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a" # Changed to Sydney AZ
}

# Route table for private subnet - only internal routes
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# EC2 Instance A
resource "aws_instance" "vm_a" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.nano"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name # COMPULSORY for SSM
  user_data              = file("${path.module}/init/vm_a_init.sh")

  tags = {
    Name = "VM-A"
  }
}

# EC2 Instance B
resource "aws_instance" "vm_b" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.nano"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name # COMPULSORY for SSM
  user_data              = file("${path.module}/init/vm_b_init.sh")

  tags = {
    Name = "VM-B"
  }
}

# S3 bucket for storing project files
resource "aws_s3_bucket" "project_files" {
  bucket_prefix = "hashicorp-runtime-files-" # AWS will append a unique suffix
  force_destroy = true                       # Allows deletion of non-empty bucket when destroying

  tags = {
    Name        = "HashiCorp Runtime Project Files"
    Environment = "development"
  }
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "project_files" {
  bucket = aws_s3_bucket.project_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "project_files" {
  bucket = aws_s3_bucket.project_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Output the bucket name for reference
output "s3_bucket_name" {
  description = "Name of the S3 bucket storing project files"
  value       = aws_s3_bucket.project_files.id
}

# Upload all files from s3 directory to S3 bucket
resource "aws_s3_object" "project_files" {
  for_each = fileset("${path.module}/s3", "*")

  bucket = aws_s3_bucket.project_files.id
  key    = each.value
  source = "${path.module}/s3/${each.value}"
  etag   = filemd5("${path.module}/s3/${each.value}")

  depends_on = [
    aws_s3_bucket.project_files,
    aws_s3_bucket_versioning.project_files,
    aws_s3_bucket_public_access_block.project_files
  ]
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-southeast-2.s3" # Changed to Sydney region
  vpc_endpoint_type = "Gateway"
}

# Add VPC Endpoint to the private route table
resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# COMPULSORY: IAM role and profile for Systems Manager
resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# COMPULSORY: Minimum required SSM policy
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Add S3 bucket access policy
resource "aws_iam_role_policy" "s3_access" {
  name = "s3-bucket-access"
  role = aws_iam_role.ssm_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListAllMyBuckets"
        ]
        Resource = [
          "arn:aws:s3:::*",  # For ListAllMyBuckets
          aws_s3_bucket.project_files.arn,
          "${aws_s3_bucket.project_files.arn}/*"
        ]
      }
    ]
  })
}

# COMPULSORY: Instance profile to attach the role to EC2s
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# Security group for SSM VPC endpoints
resource "aws_security_group" "ssm_endpoint" {
  vpc_id = aws_vpc.main.id
  name   = "ssm-endpoint-sg"

  # Allow inbound HTTPS (port 443) from instances in the private subnet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  # Allow all outbound responses back to private subnet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  tags = {
    Name = "SSM Endpoint Security Group"
  }
}

# COMPULSORY for private subnets: SSM VPC Endpoints
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-2.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.ssm_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-2.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.ssm_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-2.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.ssm_endpoint.id]
  private_dns_enabled = true
}

# Add EC2 describe permissions
resource "aws_iam_role_policy" "ec2_describe" {
  name = "ec2-describe-access"
  role = aws_iam_role.ssm_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
} 
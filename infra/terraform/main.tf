# Define the AWS provider and the region where resources will be deployed
provider "aws" {
  region = "sa-east-1" # São Paulo region – ideal for reducing latency if users or services are located in Brazil
}

# Creates a Virtual Private Cloud (VPC) to isolate all infrastructure resources for the sentiment analyzer
resource "aws_vpc" "ec2_sentiment_analyzer_vpc" {
  cidr_block           = "10.0.0.0/16" # Defines the private IP address range for the VPC (supports 65,536 IPs)
  enable_dns_hostnames = true         # Enables DNS hostnames, which is necessary for SSM and EC2 name resolution

  tags = {
    Name = "ec2_sentiment_analyzer_vpc"
  }
}

# Creates a public subnet within the VPC to host the EC2 instance
resource "aws_subnet" "ec2_sentiment_analyzer_public_subnet" {
  vpc_id     = aws_vpc.ec2_sentiment_analyzer_vpc.id
  cidr_block = "10.0.1.0/24" # Creates a subnet with up to 256 IPs

  tags = {
    Name = "ec2_sentiment_analyzer_public_subnet"
  }
}

# Creates an Internet Gateway to allow traffic between the VPC and the internet
resource "aws_internet_gateway" "ec2_sentiment_analyzer_igw" {
  vpc_id = aws_vpc.ec2_sentiment_analyzer_vpc.id

  tags = {
    Name = "ec2_sentiment_analyzer_igw"
  }
}

# Creates a route table to route internet-bound traffic through the Internet Gateway
resource "aws_route_table" "ec2_sentiment_analyzer_rt" {
  vpc_id = aws_vpc.ec2_sentiment_analyzer_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Route all outbound traffic to the Internet
    gateway_id = aws_internet_gateway.ec2_sentiment_analyzer_igw.id
  }

  tags = {
    Name = "ec2_sentiment_analyzer_rt"
  }
}

# Associates the route table with the public subnet, enabling internet access from resources in that subnet
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.ec2_sentiment_analyzer_public_subnet.id
  route_table_id = aws_route_table.ec2_sentiment_analyzer_rt.id
}

# Creates a security group with no inbound access (SSH is blocked).
# This is intentional because the EC2 will be accessed via AWS Systems Manager (SSM), not SSH.
resource "aws_security_group" "ssh_only" {
  vpc_id      = aws_vpc.ec2_sentiment_analyzer_vpc.id
  name        = "ssh_only_sg"
  description = "Security Group with no SSH - SSM Only"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "ssh_only_sg"
  }
}

# Creates an S3 bucket to store raw input comments for sentiment analysis
resource "aws_s3_bucket" "raw_comments_ec2_sentiment_analyzer" {
  bucket = "raw-comments-sa1-marcoabrantes"

  tags = {
    Name        = "EC2 Sentiment Analyzer - Raw Comments"
    Environment = "Dev"
  }
}

# Creates another S3 bucket to store the sentiment analysis results
resource "aws_s3_bucket" "sentiment_results_ec2_sentiment_analyzer" {
  bucket = "results-sentiment-sa1-marcoabrantes"

  tags = {
    Name        = "EC2 Sentiment Analyzer - Sentiment Results"
    Environment = "Dev"
  }
}

# IAM role to grant the EC2 instance permissions to assume the role and interact with AWS services
resource "aws_iam_role" "ec2_s3_access" {
  name = "ec2_s3_access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM policy that allows EC2 instance to interact with the specific S3 buckets (read/write/list)
resource "aws_iam_policy" "s3_access_policy" {
  name        = "EC2S3AccessPolicy"
  description = "Allow EC2 to access S3 buckets for sentiment analyzer"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowObjectLevelAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::raw-comments-sa1-marcoabrantes/*",
          "arn:aws:s3:::results-sentiment-sa1-marcoabrantes/*"
        ]
      },
      {
        Sid    = "AllowBucketListing"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::raw-comments-sa1-marcoabrantes",
          "arn:aws:s3:::results-sentiment-sa1-marcoabrantes"
        ]
      }
    ]
  })
}

# Attaches the custom S3 access policy to the EC2 IAM role
resource "aws_iam_role_policy_attachment" "ec2_s3_access_attach" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Grants the EC2 role access to SSM so it can be managed via AWS Systems Manager (instead of SSH)
resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Grants the EC2 role read-only access to ECR (in case Docker images are pulled from there)
resource "aws_iam_role_policy_attachment" "ecr_access_attach" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Creates an EC2 instance profile to bind the IAM role to the EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_instance_profile"
  role = aws_iam_role.ec2_s3_access.name
}

# Launches the EC2 instance that runs the sentiment analyzer
resource "aws_instance" "sentiment_analyzer" {
  ami                    = "ami-09bc0685970d93c8d" # Amazon Linux 2 AMI (region-specific)
  instance_type          = "t2.micro"              # Low-cost instance for development/testing
  subnet_id              = aws_subnet.ec2_sentiment_analyzer_public_subnet.id
  vpc_security_group_ids = [aws_security_group.ssh_only.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = file("script.sh")       # Script executed on EC2 boot for setup (e.g. install Docker, run app)
  associate_public_ip_address = true               # Necessary to allow SSM/updates when outside private network

  tags = {
    Name = "EC2 for Sentiment Analyzer"
  }
}

# Creates an Amazon ECR (Elastic Container Registry) repository to store Docker images for the sentiment analyzer
resource "aws_ecr_repository" "sentiment_analyzer" {
  name = "sentiment-analyzer" # Used if your sentiment analyzer is containerized and deployed via Docker
}

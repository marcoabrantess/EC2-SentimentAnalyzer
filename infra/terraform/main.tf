provider "aws" {
  region = "sa-east-1"
}

resource "aws_vpc" "ec2_sentiment_analyzer_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "ec2_sentiment_analyzer_vpc"
  }
}

resource "aws_subnet" "ec2_sentiment_analyzer_public_subnet" {
  vpc_id     = aws_vpc.ec2_sentiment_analyzer_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "ec2_sentiment_analyzer_public_subnet"
  }
}

resource "aws_internet_gateway" "ec2_sentiment_analyzer_igw" {
  vpc_id = aws_vpc.ec2_sentiment_analyzer_vpc.id

  tags = {
    Name = "ec2_sentiment_analyzer_igw"
  }
}

resource "aws_route_table" "ec2_sentiment_analyzer_rt" {
  vpc_id = aws_vpc.ec2_sentiment_analyzer_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ec2_sentiment_analyzer_igw.id
  }

  tags = {
    Name = "ec2_sentiment_analyzer_rt"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.ec2_sentiment_analyzer_public_subnet.id
  route_table_id = aws_route_table.ec2_sentiment_analyzer_rt.id
}

resource "aws_security_group" "ssh_only" {
  vpc_id      = aws_vpc.ec2_sentiment_analyzer_vpc.id
  name        = "ssh_only_sg"
  description = "Security Group with no SSH - SSM Only"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh_only_sg"
  }
}

resource "aws_s3_bucket" "raw_comments_ec2_sentiment_analyzer" {
  bucket = "raw-comments-sa1-marcoabrantes"

  tags = {
    Name        = "EC2 Sentiment Analyzer - Raw Comments"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "sentiment_results_ec2_sentiment_analyzer" {
  bucket = "results-sentiment-sa1-marcoabrantes"

  tags = {
    Name        = "EC2 Sentiment Analyzer - Sentiment Results"
    Environment = "Dev"
  }
}

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
          "arn:aws:s3:::sentiment-results-sa1-marcoabrantes/*"
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
          "arn:aws:s3:::sentiment-results-sa1-marcoabrantes"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ec2_s3_access_attach" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_access_attach" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_instance_profile"
  role = aws_iam_role.ec2_s3_access.name
}

resource "aws_instance" "sentiment_analyzer" {
  ami                    = "ami-09bc0685970d93c8d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.ec2_sentiment_analyzer_public_subnet.id
  vpc_security_group_ids = [aws_security_group.ssh_only.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = file("script.sh")
  associate_public_ip_address = true

  tags = {
    Name = "EC2 for Sentiment Analyzer"
  }
}

resource "aws_ecr_repository" "sentiment_analyzer" {
  name = "sentiment-analyzer"
}
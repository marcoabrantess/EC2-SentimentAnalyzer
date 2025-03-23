#!/bin/bash
set -e

echo "Updating packages"
dnf update -y
echo "System updated"

echo "Installing Docker"
dnf install -y docker
systemctl start docker
systemctl enable docker
echo "Docker installed"

echo "Uploading comentarios.txt to S3"
aws s3 cp /app/comentarios.txt s3://raw-comments-sa1-marcoabrantes/comentarios.txt
echo "Upload completed"

echo "Logging in to ECR"
aws ecr get-login-password --region sa-east-1 | sudo docker login --username AWS --password-stdin 383498687630.dkr.ecr.sa-east-1.amazonaws.com
echo "Logged in to ECR"

echo "Pulling latest image"
sudo docker pull 383498687630.dkr.ecr.sa-east-1.amazonaws.com/sentiment-analyzer:latest

echo "Removing old container"
sudo docker rm -f sentiment-analyzer || true

echo "Running container and logging output to file"
/usr/bin/sudo docker run --rm 383498687630.dkr.ecr.sa-east-1.amazonaws.com/sentiment-analyzer:latest > /var/log/sentiment.log 2>&1 &

echo "Log file will be available at /var/log/sentiment.log"

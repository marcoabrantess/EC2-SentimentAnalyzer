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

echo "Logging in to ECR"
aws ecr get-login-password --region sa-east-1 | sudo docker login --username AWS --password-stdin 383498687630.dkr.ecr.sa-east-1.amazonaws.com
echo "Logged in to ECR"

echo "Pulling latest image from ECR"
sudo docker pull 383498687630.dkr.ecr.sa-east-1.amazonaws.com/sentiment-analyzer:latest

echo "Removing old container if it exists"
sudo docker rm -f sentiment-analyzer || true

echo "Running new container"
sudo docker run -d --name sentiment-analyzer 383498687630.dkr.ecr.sa-east-1.amazonaws.com/sentiment-analyzer:latest
echo "Container is running"

echo "Container logs:"
sudo docker logs sentiment-analyzer

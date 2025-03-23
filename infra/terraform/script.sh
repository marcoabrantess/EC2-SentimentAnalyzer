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

echo "Copying application files"
mkdir -p /app
cp -r /home/ec2-user/app/* /app/
cd /app

echo "Building Docker image"
docker build -t sentiment-analyzer .

echo "Running container"
docker run -d --name sentiment-analyzer sentiment-analyzer
echo "Container is running"

echo "Uploading file to S3"
aws s3 cp /app/comentarios.txt s3://raw-comments-ec2-sentiment-analyzer-sa-east-1-marcoabrantes/

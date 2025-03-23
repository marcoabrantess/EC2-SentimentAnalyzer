# Sentiment Analyzer

This project is a Python-based sentiment analysis system designed to process user comments and determine whether their sentiment is positive, negative, or neutral. The processed data is then stored in an S3 bucket for further use or integration.

## Project Description

The main idea behind this project is to have a lightweight and flexible backend application capable of reading raw textual input (such as customer reviews or feedback), perform basic sentiment analysis, and persist the results in a centralized and scalable storage solution.

The application is packaged as a Docker container and designed to run on AWS EC2 instances. The infrastructure is provisioned using Terraform, and AWS services such as S3, IAM, and ECR are used for deployment, security, and scalability.

## Application Workflow

1. The application reads a local file named `comentarios.txt` containing sample user comments.
2. Each comment is processed through a sentiment analysis algorithm.
3. The results are uploaded to a specific S3 bucket.
4. The application is containerized using Docker for consistency across environments.
5. Docker images are pushed to AWS ECR using GitHub Actions for automated CI/CD.
6. EC2 instances pull the latest image from ECR and run the container in production.

## Technologies Used

-   Python 3.9
-   Docker
-   AWS EC2
-   AWS S3
-   AWS IAM
-   AWS ECR
-   GitHub Actions
-   Terraform

## Infrastructure Overview

The infrastructure is fully managed via Terraform. It creates:

-   A VPC with public subnet and internet access
-   A security group that limits SSH access
-   An EC2 instance running the sentiment analyzer container
-   An S3 bucket for raw input data
-   An S3 bucket for processed sentiment results
-   IAM roles and instance profile allowing EC2 to access S3
-   Optional CI/CD pipeline via GitHub Actions pushing Docker images to ECR

## Deployment Process

1. Application source code lives in the `app/` directory.
2. Infrastructure code lives in the `infra/` directory.
3. When code is pushed to the `main` branch, GitHub Actions builds and pushes the Docker image to ECR.
4. EC2 instances running in production can pull the latest image and run the container.

## Motivation

The motivation for building this project was to integrate cloud-native architecture principles into a real-world use case—processing user-generated content at scale. This application can later be extended to support additional input sources (e.g., APIs, queues), improve sentiment accuracy with machine learning models, and integrate with dashboards or notification systems.

## Author

Developed by Marco Aurélio Soares Abrantes

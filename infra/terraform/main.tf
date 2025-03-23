provider "aws" {
  region = "sa-east-1" // Região São Paulo (Brasil) oferece menor latência para usuários brasileiros
}

resource "aws_vpc" "ec2_sentiment_analyzer_vpc" {
  cidr_block           = "10.0.0.0/16" // Bloco grande que permite até 65.536 endereços IP (ideal para escalabilidade futura)
  enable_dns_hostnames = true // Ativa nomes DNS internos para que instâncias EC2 consigam se comunicar usando nomes em vez de IPs

  tags = {
    Name = "ec2_sentiment_analyzer_vpc"
  }
}

resource "aws_subnet" "ec2_sentiment_analyzer_public_subnet" {
  vpc_id     = aws_vpc.ec2_sentiment_analyzer_vpc.id
  cidr_block = "10.0.1.0/24" // Reserva 256 IPs para essa sub-rede pública, o suficiente para um ambiente pequeno/médio

  tags = {
    Name = "ec2_sentiment_analyzer_public_subnet"
  }
}

resource "aws_internet_gateway" "ec2_sentiment_analyzer_igw" {
  vpc_id = aws_vpc.ec2_sentiment_analyzer_vpc.id // Necessário para permitir saída da VPC para a internet — usada principalmente por instâncias públicas

  tags = {
    Name = "ec2_sentiment_analyzer_igw"
  }
}

resource "aws_route_table" "ec2_sentiment_analyzer_rt" {
  vpc_id = aws_vpc.ec2_sentiment_analyzer_vpc.id

  route = {
    cidr_block = "0.0.0.0/0" // Define o caminho padrão para tráfego externo
    gateway_id = aws_internet_gateway.ec2_sentiment_analyzer_igw
  } // Faz com que instâncias nessa rota tenham acesso à internet — essencial para baixar pacotes, acessar APIs etc.

  tags = {
    Name = "ec2_sentiment_analyzer_rt"
  }
}

resource "aws_security_group" "ssh_only" {
  vpc_id     = aws_vpc.ec2_sentiment_analyzer_vpc.id
  name       = "ssh_only_sg"
  description = "Security Group allowing ssh access only"

  ingress {
    description = "Allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] // Restringe o acesso SSH a partir de dentro da própria VPC — boa prática em ambientes com bastion host
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" // Permite que a instância envie qualquer tipo de tráfego para fora, necessário para atualizações, API calls etc.
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh_only_sg"
  }
}

resource "aws_s3_bucket" "raw_comments_ec2_sentiment_analyzer_sa_east_1_marcoabrantes" {
  bucket = "raw-comments-ec2-sentiment-analyzer-sa-east-1-marcoabrantes" // Armazena dados brutos de comentários para análise

  tags = {
    Name        = "EC2 Sentiment Analyzer - Raw Comments"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "sentiment_results_ec2_sentiment_analyzer_sa_east_1_marcoabrantes" {
  bucket = "sentiment-results-ec2-sentiment-analyzer-sa-east-1-marcoabrantes" // Armazena os resultados processados da análise de sentimento

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
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  }) // Permite que a instância EC2 assuma a role, essencial para permissões de runtime via Instance Profile
}

resource "aws_iam_policy" "s3_access_policy" {
  name        = "EC2S3AccessPolicy"
  description = "Allow EC2 to GetObject and PutObject in S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::raw-comments-ec2-sentiment-analyzer-sa-east-1-marcoabrantes/*",
          "arn:aws:s3:::sentiment-results-ec2-sentiment-analyzer-sa-east-1-marcoabrantes/*"
        ]
      }
    ]
  }) // Permissões estritamente limitadas a objetos nos buckets relevantes, reduzindo riscos e evitando over-permissioning
}

resource "aws_iam_policy_attachment" "ec2_s3_access_attach" {
  name       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
  roles      = [aws_iam_role.ec2_s3_access.name] // Garante que a policy está ligada corretamente à Role assumida pela EC2
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_instance_profile"
  role = aws_iam_role.ec2_s3_access.name
} // Cria um "wrapper" necessário para associar a IAM Role a uma instância EC2 de forma automatizada e segura

resource "aws_instance" "sentiment_analyzer" {
  ami           = "ami-09bc0685970d93c8d" // AMI oficial e atualizada do Amazon Linux 2023 com suporte a kernel 6.1
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.ec2_sentiment_analyzer_public_subnet.id

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name // Conecta a instância à IAM Role, permitindo acesso controlado ao S3

  user_data = file("script.sh")

  tags = {
    Name = "EC2 for Sentiment Analyzer"
  }
} // Instância leve, ideal para workloads de desenvolvimento e testes iniciais do analisador de sentimento

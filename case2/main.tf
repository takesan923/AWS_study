# AWSプロバイダ設定
provider "aws" {
  profile = "default"
  region  = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "takeru-vpc"
  }
}

# Publicサブネット-ALB
resource "aws_subnet" "public_ALB1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-northeast-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet1"
  }
}

resource "aws_subnet" "public_ALB2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet2"
  }
}

# Ptivateサブネット-RDS
resource "aws_subnet" "private_RDS1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1b"

  tags = {
    Name = "private-subnet1"
  }
}

resource "aws_subnet" "private_RDS2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "private-subnet2"
  }
}

# Privateサブネット-EC2
resource "aws_subnet" "private_ec2-1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-northeast-1b"
  tags              = { Name = "private-ec2-subnet-1b" }
}

resource "aws_subnet" "private_ec2-1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.7.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "private-ec2-subnet-1c" }
}

# Internet GateWay(public)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# NAT Gateway用EIP
resource "aws_eip" "nat" {
  domain = "vpc"
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_ALB1.id
  tags          = { Name = "main-nat-gw" }
}

# EC2用Privateルートテーブル
resource "aws_route_table" "private_ec2" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "private-ec2-rt" }
}

# ルートテーブル(public)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# ルートテーブルとサブネットの関連付け
resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_ALB1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_ALB2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_ec2-1b" {
  subnet_id      = aws_subnet.private_ec2-1b.id
  route_table_id = aws_route_table.private_ec2.id
}

resource "aws_route_table_association" "private_ec2-1c" {
  subnet_id      = aws_subnet.private_ec2-1c.id
  route_table_id = aws_route_table.private_ec2.id
}

# セキュリティグループ
# ALB:Grobal to ALB
resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

# EC2:ALB to  EC2 + SSH
resource "aws_security_group" "ec2" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-sg" }
}

# RDS:EC2 to RDS(only 3306)
resource "aws_security_group" "rds" {
  name   = "rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}

# AMI取得
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2
resource "aws_instance" "wordpress" {
  ami                         = data.aws_ami.amazon_linux2.id
  instance_type               = "t2.micro"
  count                       = 2
  subnet_id                   = [aws_subnet.private_ec2-1b.id, aws_subnet.private_ec2-1c.id][count.index]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    # Apache + PHP インストール
    amazon-linux-extras enable php8.1

    yum install -y httpd php php-mysqlnd php-mbstring php-xml
    systemctl start httpd
    systemctl enable httpd

    # WordPress
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    mv wordpress/* /var/www/html/
    rm -rf wordpress latest.tar.gz

    # wp-config.phpの設定
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php                                                                                                                                        
    sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php                                                                                                                                     
    sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php                                                                                                                                             
    sed -i "s/password_here/${var.db_root_pass}/" /var/www/html/wp-config.php
    sed -i "s/localhost/${aws_db_instance.wordpress.address}/" /var/www/html/wp-config.php

    # デフォルトページ削除
    rm -f /etc/httpd/conf.d/welcome.conf

    # Apache再起動
    systemctl restart httpd
  EOF

  tags = {
    Name = "kono-case2-server-${count.index + 1}"
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_ALB1.id, aws_subnet.public_ALB2.id]

  tags = { Name = "wordpress-alb" }
}

resource "aws_lb_target_group" "wordpress" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = { Name = "wordpress-tg" }
}

resource "aws_lb_target_group_attachment" "wordpress" {
  target_group_arn = aws_lb_target_group.wordpress.arn
  count            = 2
  target_id        = aws_instance.wordpress[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

# CloudFront
resource "aws_cloudfront_distribution" "wordpress" {
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled = true

  # 動的ページはキャッシュしない
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    forwarded_values {
      query_string = true
      headers      = ["Host", "CloudFront-Forwarded-Proto"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # 静的コンテンツはキャッシュする
  ordered_cache_behavior {
    path_pattern     = "/wp-content/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["JP"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "wordpress-cf" }
}

# DBサブネットグループ
resource "aws_db_subnet_group" "main" {
  name       = "wordpress-db-subnet-group"
  subnet_ids = [aws_subnet.private_RDS1.id, aws_subnet.private_RDS2.id]

  tags = { Name = "wordpress-db-subnet-group" }
}

# RDSインスタンス
resource "aws_db_instance" "wordpress" {
  identifier              = "wordpress-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "wordpress"
  username                = "wpuser"
  password                = var.db_root_pass
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  publicly_accessible     = false
  storage_encrypted       = true

  tags = { Name = "wordpress-db" }
}

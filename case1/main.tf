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

# Publicサブネット
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-northeast-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Ptivateサブネット
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1b"

  tags = {
    Name = "private-subnet"
  }
}

# Internet GateWay(public)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
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
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# セキュリティグループ
resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
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
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    # Apache + PHP インストール
    amazon-linux-extras enable php8.1

    yum install -y httpd php php-mysqlnd php-mbstring php-xml
    systemctl start httpd
    systemctl enable httpd

    # MySQLインストール
    yum install -y mariadb-server
    systemctl start mariadb
    systemctl enable mariadb

    # WordPress
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    mv wordpress/* /var/www/html/
    rm -rf wordpress latest.tar.gz

    # 起動完了を待つ
    until mysqladmin ping --silent; do
      sleep 1
    done

    # DB初期化
    db_pass='${var.db_root_pass}'                                                                                                                                                                            
    mysql -u root -e "CREATE DATABASE wordpress CHARACTER SET utf8mb4;"
    mysql -u root -e "CREATE USER 'wpuser'@'localhost' IDENTIFIED BY '$db_pass';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';"
    mysql -u root -e "FLUSH PRIVILEGES;"

    # wp-config.phpの作成
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
    sed -i "s/password_here/$db_pass/" /var/www/html/wp-config.php

    # デフォルトページ削除
    rm -f /etc/httpd/conf.d/welcome.conf

    # Apache再起動
    systemctl restart httpd
  EOF

  tags = {
    Name = "kono-case1-server"
  }
}

# Elastic IPの取得
resource "aws_eip" "wordpress" {
  domain = "vpc"
}

# EC2に割り当て
resource "aws_eip_association" "wordpress" {
  instance_id   = aws_instance.wordpress.id
  allocation_id = aws_eip.wordpress.id
}

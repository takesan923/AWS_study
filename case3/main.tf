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

# Privateサブネット-ECS
resource "aws_subnet" "private_ecs-1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-northeast-1b"
  tags              = { Name = "private-ecs-subnet-1b" }
}

resource "aws_subnet" "private_ecs-1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.7.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "private-ecs-subnet-1c" }
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

# ECS用Privateルートテーブル
resource "aws_route_table" "private_ecs" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "private-ecs-rt" }
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

resource "aws_route_table_association" "private_ecs-1b" {
  subnet_id      = aws_subnet.private_ecs-1b.id
  route_table_id = aws_route_table.private_ecs.id
}

resource "aws_route_table_association" "private_ecs-1c" {
  subnet_id      = aws_subnet.private_ecs-1c.id
  route_table_id = aws_route_table.private_ecs.id
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

# ECS
resource "aws_security_group" "ecs" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ecs-sg" }
}

# RDS:EC2 to RDS(only 3306)
resource "aws_security_group" "rds" {
  name   = "rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}

# EFS
resource "aws_security_group" "efs" {
  name   = "efs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "efs-sg" }
}

# Secrets Manager
resource "aws_secretsmanager_secret" "db_pass" {
  name                    = "wordpress-db-password"
  tags                    = { Name = "wordpress-db-password" }
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_pass" {
  secret_id     = aws_secretsmanager_secret.db_pass.id
  secret_string = var.db_root_pass
}

# IAMロール
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_secrets" {
  name = "ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.db_pass.arn
    }]
  })
}

# EFSファイルシステム
resource "aws_efs_file_system" "wordpress" {
  encrypted = true
  tags      = { Name = "wordpress-efs" }
}

# マウントターゲット
resource "aws_efs_mount_target" "wordpress_1b" {
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = aws_subnet.private_ecs-1b.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "wordpress_1c" {
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = aws_subnet.private_ecs-1c.id
  security_groups = [aws_security_group.efs.id]
}

# ECSクラスター
resource "aws_ecs_cluster" "main" {
  name = "wordpress-cluster"
  tags = { Name = "wordpress-cluster" }
}

# タスク
resource "aws_ecs_task_definition" "wordpress" {
  family                   = "wordpress"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "wordpress"
    image = "wordpress:latest"
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    mountPoints = [{
      sourceVolume  = "wordpress-data"
      containerPath = "/var/www/html/wp-content"
    }]

    environment = [
      { name = "WORDPRESS_DB_HOST", value = aws_db_instance.wordpress.address },
      { name = "WORDPRESS_DB_NAME", value = "wordpress" },
      { name = "WORDPRESS_DB_USER", value = "wpuser" },
      { name = "WORDPRESS_CONFIG_EXTRA", value = "if (isset($_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO']) && strpos($_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO'], 'https') !== false) { $_SERVER['HTTPS'] ='on'; } define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST']); define('WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST']); define('FORCE_SSL_ADMIN', true);" }
    ]

    secrets = [
      { name = "WORDPRESS_DB_PASSWORD", valueFrom = aws_secretsmanager_secret.db_pass.arn }
    ]
  }])

  volume {
    name = "wordpress-data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wordpress.id
      root_directory = "/"
    }
  }
}

# ECSサービス
resource "aws_ecs_service" "wordpress" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_ecs-1b.id, aws_subnet.private_ecs-1c.id]
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress.arn
    container_name   = "wordpress"
    container_port   = 80
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
  name        = "wordpress-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = { Name = "wordpress-tg" }
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

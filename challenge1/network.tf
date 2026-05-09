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
resource "aws_subnet" "public_alb_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-northeast-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1b"
  }
}

resource "aws_subnet" "public_alb_1c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1c"
  }
}

# Ptivateサブネット-RDS
resource "aws_subnet" "private_rds_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1b"

  tags = {
    Name = "private-rds-1b"
  }
}

resource "aws_subnet" "private_rds_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "private-rds-1c"
  }
}

# Privateサブネット-ECS
resource "aws_subnet" "private_ecs_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-northeast-1b"
  tags              = { Name = "private-ecs-1b" }
}

resource "aws_subnet" "private_ecs_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.7.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "private-ecs-1c" }
}

# Publicサブネット-Internet GateWay
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

# Publicサブネット-NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_alb_1b.id
  tags          = { Name = "main-nat-gw" }
}

# ECS用ルートテーブル(private)
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
  subnet_id      = aws_subnet.public_alb_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_alb_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_ecs_1b" {
  subnet_id      = aws_subnet.private_ecs_1b.id
  route_table_id = aws_route_table.private_ecs.id
}

resource "aws_route_table_association" "private_ecs_1c" {
  subnet_id      = aws_subnet.private_ecs_1c.id
  route_table_id = aws_route_table.private_ecs.id
}

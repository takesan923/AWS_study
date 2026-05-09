# RDSインスタンス
resource "aws_db_instance" "main" {
  identifier              = "db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "app_db"
  username                = "app_user"
  password                = var.db_root_pass
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  publicly_accessible     = false
  storage_encrypted       = true

  tags = { Name = "db" }
}

# DBサブネットグループ
resource "aws_db_subnet_group" "main" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_rds_1b.id, aws_subnet.private_rds_1c.id]

  tags = { Name = "db-subnet-group" }
}

# Secrets Manager
resource "aws_secretsmanager_secret" "db_pass" {
  name                    = "db-password"
  recovery_window_in_days = 0
  tags                    = { Name = "db-password" }
}

resource "aws_secretsmanager_secret_version" "db_pass" {
  secret_id     = aws_secretsmanager_secret.db_pass.id
  secret_string = var.db_root_pass
}

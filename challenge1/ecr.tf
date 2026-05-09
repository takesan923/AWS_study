# ECR
resource "aws_ecr_repository" "api" {
  name                 = "api-container"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "api-ecr" }
}

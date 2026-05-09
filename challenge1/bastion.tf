# 踏み台EC2
resource "aws_instance" "bastion" {
  ami                    = "ami-0599b6e53ca798bb2" # Amazon Linux 2023 (ap-northeast-1)
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_alb_1b.id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = { Name = "bastion" }
}

# IAMロール（SSM用）
resource "aws_iam_role" "bastion" {
  name = "bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-profile"
  role = aws_iam_role.bastion.name
}

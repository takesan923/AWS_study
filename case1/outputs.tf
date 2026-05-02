output "elastic_ip" {
  value = aws_eip.wordpress.public_ip
}

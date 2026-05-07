output "cloudfront_url" {
  value = aws_cloudfront_distribution.wordpress.domain_name
}

output "alb_dns" {
  value = aws_lb.main.dns_name
}

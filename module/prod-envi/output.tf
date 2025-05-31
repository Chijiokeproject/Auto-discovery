output "prod-sg" {
  value       = aws_security_group.prod-sg.id
  description = "Security group ID for the prod environment"
}
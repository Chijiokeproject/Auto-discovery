output "prod-sg" {
  value       = aws_security_group.prod-sg.id
  description = "Security group ID for the prod environment"
}
output "target_group_arn" {
  value = aws_lb_target_group.prod_target_group.arn
}

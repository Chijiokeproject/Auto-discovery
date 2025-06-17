output "stage-sg" {
  value       = aws_security_group.stage-sg.id
  description = "Security group ID for the stage environment"
}
output "target_group_arn" {
  value = aws_lb_target_group.stage_target_group.arn
}
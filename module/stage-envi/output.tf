output "stage-sg" {
  value       = aws_security_group.stage-sg.id
  description = "Security group ID for the stage environment"
}
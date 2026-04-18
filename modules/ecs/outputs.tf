output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "service_name" {
  value = aws_ecs_service.api.name
}

output "task_exec_role_arn" {
  value = aws_iam_role.task_exec.arn
}

output "task_role_arn" {
  value       = aws_iam_role.task.arn
  description = "Application task role — attach additional policies here as the app grows"
}

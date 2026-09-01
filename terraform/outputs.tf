output "api_endpoint" {
  description = "Base URL for the deployed API"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "tasks_table_name" {
  value = aws_dynamodb_table.tasks.name
}

output "task_events_topic_arn" {
  value = aws_sns_topic.task_events.arn
}

output "infra_alerts_topic_arn" {
  value = aws_sns_topic.infra_alerts.arn
}
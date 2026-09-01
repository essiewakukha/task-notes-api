variable "project_name" {
  description = "Short name used to prefix all resources"
  type        = string
  default     = "task-notes-api"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL used to post infra alerts and task notifications"
  type        = string
  sensitive   = true
  default     = "" # supply via -var or TF_VAR_slack_webhook_url in CI secrets
}
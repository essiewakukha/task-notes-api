# Alarm on the notify Lambda specifically: if this fails, task notifications
# are silently being dropped (after 3 retries, into the DLQ) and nobody
# would otherwise know. That's exactly the kind of failure alerting exists to catch.
resource "aws_cloudwatch_metric_alarm" "notify_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-notify-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Notify Lambda has thrown one or more errors in the last 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.notify.function_name
  }

  alarm_actions = [aws_sns_topic.infra_alerts.arn]
  ok_actions    = [aws_sns_topic.infra_alerts.arn]
}

# Alarm on messages landing in the DLQ - a stronger signal than individual
# Lambda errors, since it means we've exhausted retries.
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-${var.environment}-notifications-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Messages have landed in the task-notifications DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.task_notifications_dlq.name
  }

  alarm_actions = [aws_sns_topic.infra_alerts.arn]
}

# Alarm on API Gateway 5xx rate - catches integration failures across any
# of the CRUD Lambdas without needing one alarm per function.
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "API Gateway returned one or more 5xx responses in the last 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.this.id
  }

  alarm_actions = [aws_sns_topic.infra_alerts.arn]
}
# --- Task events topic ---
# Every CRUD Lambda publishes here (task created / updated / completed / deleted).
# Using SNS as the entry point (not SQS directly) means we can fan this out to
# multiple future subscribers - e.g. an analytics pipeline or a search indexer -
# without ever touching the API Lambdas again.
resource "aws_sns_topic" "task_events" {
  name = "${var.project_name}-${var.environment}-task-events"
}

# --- Dead-letter queue for notifications that fail repeatedly ---
resource "aws_sqs_queue" "task_notifications_dlq" {
  name                      = "${var.project_name}-${var.environment}-task-notifications-dlq"
  message_retention_seconds = 1209600 # 14 days, max out the window to give time to investigate
}

# --- Main notifications queue, subscribed to the task-events topic ---
resource "aws_sqs_queue" "task_notifications" {
  name                       = "${var.project_name}-${var.environment}-task-notifications"
  visibility_timeout_seconds = 30 # should be >= notify Lambda timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.task_notifications_dlq.arn
    maxReceiveCount      = 3
  })
}

# Allow the SNS topic to deliver messages into the SQS queue
data "aws_iam_policy_document" "task_notifications_queue_policy" {
  statement {
    sid     = "AllowSNSPublish"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [aws_sqs_queue.task_notifications.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.task_events.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "task_notifications" {
  queue_url = aws_sqs_queue.task_notifications.id
  policy    = data.aws_iam_policy_document.task_notifications_queue_policy.json
}

resource "aws_sns_topic_subscription" "task_notifications" {
  topic_arn = aws_sns_topic.task_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.task_notifications.arn
}

# --- Infra alerts topic (CloudWatch Alarms publish here) ---
resource "aws_sns_topic" "infra_alerts" {
  name = "${var.project_name}-${var.environment}-infra-alerts"
}
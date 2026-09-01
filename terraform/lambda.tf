# Each handler is bundled independently by esbuild in CI (see package.json
# "build" script) into src/dist/<handler>/index.js. Terraform just zips

locals {
  handlers = ["createTask", "getTask", "listTasks", "updateTask", "deleteTask"]
}

data "archive_file" "api_handlers" {
  for_each    = toset(local.handlers)
  type        = "zip"
  source_dir  = "${path.module}/../src/dist/${each.value}"
  output_path = "${path.module}/../src/dist/${each.value}.zip"
}

resource "aws_lambda_function" "api" {
  for_each = toset(local.handlers)

  function_name = "${var.project_name}-${var.environment}-${each.value}"
  role          = aws_iam_role.api_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10
  memory_size   = 256

  filename         = data.archive_file.api_handlers[each.value].output_path
  source_code_hash = data.archive_file.api_handlers[each.value].output_base64sha256

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.tasks.name
      TASK_TOPIC_ARN = aws_sns_topic.task_events.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "api" {
  for_each          = toset(local.handlers)
  name              = "/aws/lambda/${aws_lambda_function.api[each.value].function_name}"
  retention_in_days = var.log_retention_days
}

# --- Notification Lambda: consumes SQS, posts to Slack ---
data "archive_file" "notify" {
  type        = "zip"
  source_dir  = "${path.module}/../src/dist/notify"
  output_path = "${path.module}/../src/dist/notify.zip"
}

resource "aws_lambda_function" "notify" {
  function_name = "${var.project_name}-${var.environment}-notify"
  role          = aws_iam_role.notify_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.notify.output_path
  source_code_hash = data.archive_file.notify.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_cloudwatch_log_group" "notify" {
  name              = "/aws/lambda/${aws_lambda_function.notify.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_event_source_mapping" "notify_from_sqs" {
  event_source_arn = aws_sqs_queue.task_notifications.arn
  function_name    = aws_lambda_function.notify.arn
  batch_size       = 5
}

# --- Alert Lambda: consumes CloudWatch Alarm SNS topic, posts to Slack ---
data "archive_file" "alert" {
  type        = "zip"
  source_dir  = "${path.module}/../src/dist/alert"
  output_path = "${path.module}/../src/dist/alert.zip"
}

resource "aws_lambda_function" "alert" {
  function_name = "${var.project_name}-${var.environment}-alert"
  role          = aws_iam_role.alert_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.alert.output_path
  source_code_hash = data.archive_file.alert.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_cloudwatch_log_group" "alert" {
  name              = "/aws/lambda/${aws_lambda_function.alert.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_sns_topic_subscription" "alert_from_infra_alerts" {
  topic_arn = aws_sns_topic.infra_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert.arn
}

resource "aws_lambda_permission" "allow_sns_invoke_alert" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.infra_alerts.arn
}
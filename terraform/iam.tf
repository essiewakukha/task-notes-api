# --- Shared assume-role policy for all Lambda functions ---
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Role for the CRUD API Lambdas (read/write DynamoDB + publish task events) ---
resource "aws_iam_role" "api_lambda" {
  name               = "${var.project_name}-${var.environment}-api-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "api_lambda_permissions" {
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query",
    ]
    resources = [aws_dynamodb_table.tasks.arn]
  }

  statement {
    sid       = "PublishTaskEvents"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.task_events.arn]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "api_lambda_permissions" {
  name   = "${var.project_name}-${var.environment}-api-lambda-permissions"
  role   = aws_iam_role.api_lambda.id
  policy = data.aws_iam_policy_document.api_lambda_permissions.json
}

# --- Role for the notification Lambda (consumes SQS, posts to Slack) ---
resource "aws_iam_role" "notify_lambda" {
  name               = "${var.project_name}-${var.environment}-notify-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "notify_lambda_permissions" {
  statement {
    sid    = "ConsumeSQS"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.task_notifications.arn]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "notify_lambda_permissions" {
  name   = "${var.project_name}-${var.environment}-notify-lambda-permissions"
  role   = aws_iam_role.notify_lambda.id
  policy = data.aws_iam_policy_document.notify_lambda_permissions.json
}

# --- Role for the infra-alerts Lambda (consumes CloudWatch alarm SNS topic, posts to Slack) ---
resource "aws_iam_role" "alert_lambda" {
  name               = "${var.project_name}-${var.environment}-alert-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "alert_lambda_permissions" {
  name = "${var.project_name}-${var.environment}-alert-lambda-permissions"
  role = aws_iam_role.alert_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "Logs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}
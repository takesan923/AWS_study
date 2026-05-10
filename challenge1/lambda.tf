data "archive_file" "notify_slack" {
  type        = "zip"
  source_file = "${path.module}/lambda/notify_slack.py"
  output_path = "${path.module}/lambda/notify_slack.zip"
}

resource "aws_lambda_function" "notify_slack" {
  function_name    = "notify-slack"
  filename         = data.archive_file.notify_slack.output_path
  source_code_hash = data.archive_file.notify_slack.output_base64sha256
  handler          = "notify_slack.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_notify_slack.arn

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = { Name = "notify-slack" }
}

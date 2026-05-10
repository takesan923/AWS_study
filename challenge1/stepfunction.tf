resource "aws_sfn_state_machine" "notify" {
  name     = "task-notification"
  role_arn = aws_iam_role.sfn_notify.arn

  definition = jsonencode({
    Comment = "タスク作成通知ワークフロー"
    StartAt = "FormatMessage"
    States = {
      FormatMessage = {
        Type = "Pass"
        Parameters = {
          "message.$" = "States.Format('新しいタスクが作成されました\nID: {}\nタイトル:{}\nステータス: {}', $.detail.task_id, $.detail.title, $.detail.status)"
        }
        Next = "NotifySlack"
      }
      NotifySlack = {
        Type     = "Task"
        Resource = aws_lambda_function.notify_slack.arn
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailed"
        }]
        Next = "Success"
      }
      Success = {
        Type = "Succeed"
      }
      NotifyFailed = {
        Type  = "Fail"
        Error = "NotificationFailed"
        Cause = "Slack通知がリトライ後も失敗しました"
      }
    }
  })

  tags = { Name = "task-notification" }
}

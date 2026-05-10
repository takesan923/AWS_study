resource "aws_cloudwatch_event_bus" "task_events" {
  name = "task-events"
}

resource "aws_cloudwatch_event_rule" "task_created" {
  name           = "task-created"
  event_bus_name = aws_cloudwatch_event_bus.task_events.name

  event_pattern = jsonencode({
    source      = ["api.tasks"]
    detail-type = ["TaskCreated"]
  })
}

resource "aws_cloudwatch_event_target" "sfn" {
  rule           = aws_cloudwatch_event_rule.task_created.name
  event_bus_name = aws_cloudwatch_event_bus.task_events.name
  arn            = aws_sfn_state_machine.notify.arn
  role_arn       = aws_iam_role.eventbridge_sfn.arn
}

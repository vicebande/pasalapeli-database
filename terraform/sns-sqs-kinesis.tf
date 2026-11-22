# SNS Topic for events
resource "aws_sns_topic" "events" {
  name = "pasalapeli-events"

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-events"
  }
}

# SQS Queue for events
resource "aws_sqs_queue" "events" {
  name = "pasalapeli-events-queue"

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-events-queue"
  }
}

# SNS -> SQS subscription
resource "aws_sns_topic_subscription" "events_sqs" {
  topic_arn = aws_sns_topic.events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.events.arn
}

# Kinesis Stream for metrics (retention default 24h, sin IncreaseStreamRetentionPeriod
# para evitar denegación por SCP de la organización)
resource "aws_kinesis_stream" "metrics" {
  name             = "pasalapeli-metrics-stream"
  shard_count      = 1
  retention_period = 24

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-metrics-stream"
  }
}

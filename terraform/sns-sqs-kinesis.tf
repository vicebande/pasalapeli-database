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
  
  retention_period = 86400  # 24 hours
  
  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-events-queue"
  }
}

# SQS Subscription
resource "aws_sqs_queue_subscription" "events" {
  queue_arn = aws_sqs_queue.events.arn
  topic_arn = aws_sns_topic.events.arn
}

# Kinesis Stream for metrics
resource "aws_kinesis_stream" "metrics" {
  name               = "pasalapeli-metrics-stream"
  shard_count        = 1
  retention_period   = 24  # hours
  
  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-metrics-stream"
  }
}

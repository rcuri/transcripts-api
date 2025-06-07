resource "aws_sqs_queue" "transcripts_queue" {
  name                        = "transcripts-processing-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = 18  # 3x your Lambda timeout (6s)
  message_retention_seconds   = 1209600  # 14 days
  receive_wait_time_seconds   = 10
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.transcripts_dlq.arn
    maxReceiveCount     = 1  # Retry 3 times before sending to DLQ
  })
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "transcripts_dlq" {
  name                      = "transcripts-processing-dlq.fifo"
  fifo_queue               = true
  message_retention_seconds = 1209600  # 14 days
}
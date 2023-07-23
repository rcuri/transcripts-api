resource "aws_sqs_queue" "transcripts_queue" {
  name                        = "transcripts-processing-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}
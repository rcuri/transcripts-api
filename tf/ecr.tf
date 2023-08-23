resource "aws_ecr_repository" "drigo_transcripts" {
  name = "drigo/transcripts"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    env = "prod"
  }
}
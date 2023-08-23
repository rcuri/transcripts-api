resource "aws_ecr_repository" "drigo_transcripts" {
  repository_name = "drigo/transcripts"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    env = "prod"
  }
}
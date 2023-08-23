resource "aws_ecrpublic_repository" "drigo_transcripts" {
  repository_name = "drigo/transcripts"

  tags = {
    env = "prod"
  }
}
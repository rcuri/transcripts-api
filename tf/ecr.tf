resource "aws_ecrpublic_repository" "drigo_transcripts" {
  provider = provider.aws.region

  repository_name = "drigo/transcripts"

  tags = {
    env = "prod"
  }
}
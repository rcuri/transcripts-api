resource "aws_ecrpublic_repository" "drigo_transcripts" {
  provider = provider.aws.us_east_1

  repository_name = "drigo/transcripts"

  tags = {
    env = "prod"
  }
}
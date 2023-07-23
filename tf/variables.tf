data "aws_secretsmanager_secret" "db_prod_creds" {
 name = "prod/transcripts/postgreSQL"
}

data "aws_secretsmanager_secret" "db_dev_creds" {
 name = "dev/transcripts/postgreSQL"
}

data "aws_secretsmanager_secret" "openai_api_key" {
 name = "openai_api_key"
}

data "aws_secretsmanager_secret_version" "db_prod_creds" {
 secret_id = data.aws_secretsmanager_secret.db_prod_creds.id
}

data "aws_secretsmanager_secret_version" "db_dev_creds" {
 secret_id = data.aws_secretsmanager_secret.db_dev_creds.id
}

data "aws_secretsmanager_secret_version" "openai_api_key" {
 secret_id = data.aws_secretsmanager_secret.openai_api_key.id
}

locals {
    db_prod_credentials = sensitive(jsondecode(
        data.aws_secretsmanager_secret_version.db_prod_creds.secret_string
    ))

    db_dev_credentials = sensitive(jsondecode(
        data.aws_secretsmanager_secret_version.db_dev_creds.secret_string
    ))

    openai_api_key = sensitive(
        data.aws_secretsmanager_secret_version.openai_api_key.secret_string
    )
}
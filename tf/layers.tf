#define variables
locals {
  layer_zip_path    = "python.zip"
  layer_name        = "my_lambda_requirements_layer"
  requirements_path = "${path.root}/../requirements.txt"
}

# create zip file from requirements.txt. Triggers only when the file is updated
resource "null_resource" "lambda_layer" {
  triggers = {
    always_run = "${timestamp()}"
  }
  # the command to install python and dependencies to the machine and zips
  provisioner "local-exec" {
    command = <<EOT
      pwd
      ls
      mkdir python
      pip install -r ${local.requirements_path} -t python/
      ls python
    EOT
  }
}

data "archive_file" "lambda_layer" {
  type = "zip"
  depends_on = [null_resource.lambda_layer]
  excludes   = [
    "venv",
  ]
  source_dir  = "${path.root}/python"
  output_path = "${path.root}/../layers/python.zip"
}

# define existing bucket for storing lambda layers
resource "aws_s3_bucket" "lambda_layer_bucket" {
  bucket = "my-lambda-layer-bucket"
  force_destroy = true
}

# upload zip file to s3
resource "aws_s3_object" "lambda_layer_zip" {
  bucket     = aws_s3_bucket.lambda_layer_bucket.id
  key        = "lambda_layers/${local.layer_name}/${local.layer_zip_path}"
  source     = data.archive_file.lambda_layer.output_path
  depends_on = [null_resource.lambda_layer] # triggered only if the zip file is created
}

# create lambda layer from s3 object
resource "aws_lambda_layer_version" "my-lambda-layer" {
  s3_bucket           = aws_s3_bucket.lambda_layer_bucket.id
  s3_key              = aws_s3_object.lambda_layer_zip.key
  layer_name          = local.layer_name
  compatible_runtimes = ["python3.8"]
  skip_destroy        = true
  depends_on          = [aws_s3_object.lambda_layer_zip] # triggered only if the zip file is uploaded to the bucket
}
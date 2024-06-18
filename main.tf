terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 1.2.0"
}

variable "HOME" {
  type        = string
  description = "the absolute path to your home directory"
}

provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["${var.HOME}/.aws/credentials"]
}

resource "random_id" "bucket_id" {
  byte_length = 6
}

resource "aws_s3_bucket" "data_log" {
  bucket = "data-log-${random_id.bucket_id.hex}"
}

resource "aws_iam_role" "data_vis_db_role" {
  name = "data_vis_db_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowLambdaExecution",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "AWSLambdaBasicExecutionRole"
  roles      = [aws_iam_role.data_vis_db_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "zipped_lambda" {
  type        = "zip"
  source_file = "${path.module}/main_lambda.py"
  output_path = "${path.module}/function.zip"
}

resource "aws_s3_object" "zipped_lambda" {
  bucket = aws_s3_bucket.data_log.id
  key    = "function.zip"
  source = data.archive_file.zipped_lambda.output_path

  etag = filemd5(data.archive_file.zipped_lambda.output_path)
}

resource "aws_lambda_function" "my_data_lambda" {
  function_name = "my_data_vis_func"
  s3_bucket     = aws_s3_bucket.data_log.id
  s3_key        = aws_s3_object.zipped_lambda.key

  runtime = "python3.9"
  handler = "main_lambda.lambda_handler"

  source_code_hash = data.archive_file.zipped_lambda.output_base64sha256

  role = aws_iam_role.data_vis_db_role.arn
}

resource "aws_api_gateway_rest_api" "data_vis_api" {
  name        = "data_vis_myrestapi"
  description = "This is an REST API for data visualization"
}

resource "aws_api_gateway_resource" "resource_api" {
  rest_api_id = aws_api_gateway_rest_api.data_vis_api.id
  parent_id   = aws_api_gateway_rest_api.data_vis_api.root_resource_id
  path_part   = "data"
}

resource "aws_api_gateway_method" "methods" {
  for_each      = toset(["OPTIONS", "PUT", "DELETE", "GET", "POST"])
  rest_api_id   = aws_api_gateway_rest_api.data_vis_api.id
  resource_id   = aws_api_gateway_resource.resource_api.id
  http_method   = each.key
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "method_responses" {
  for_each    = aws_api_gateway_method.methods
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "integrations" {
  for_each                = aws_api_gateway_method.methods
  rest_api_id             = each.value.rest_api_id
  resource_id             = each.value.resource_id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_data_lambda.invoke_arn
}

resource "aws_api_gateway_integration_response" "integration_responses" {
  for_each    = aws_api_gateway_method.methods
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, PUT, POST, DELETE, OPTIONS'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
  }

  depends_on = [aws_api_gateway_integration.integrations]
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_data_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.data_vis_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.integrations]
  rest_api_id = aws_api_gateway_rest_api.data_vis_api.id
  stage_name  = "dev"
}

output "lambda_function_arn" {
  value = aws_lambda_function.my_data_lambda.arn
}

output "api_invoke_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/data"
}

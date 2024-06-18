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

# Define a variable for the home directory
variable "HOME" {
  type        = string
  description = "the absolute path to your home directory"
}

# Configure the AWS provider with credentials and region
provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["${var.HOME}/.aws/credentials"]
}

# Generate a random ID for unique bucket naming
resource "random_id" "bucket_id" {
  byte_length = 6
}

# Create an S3 bucket with a unique name
resource "aws_s3_bucket" "data_log" {
  bucket = "data-log-${random_id.bucket_id.hex}"
}

# Create an IAM role for the Lambda function
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

# Attach the AWSLambdaBasicExecutionRole policy to the IAM role
resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "AWSLambdaBasicExecutionRole"
  roles      = [aws_iam_role.data_vis_db_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Zip the lambda
data "archive_file" "zipped_lambda" {
  type        = "zip"
  source_file = "${path.module}/main_lambda.py"
  output_path = "${path.module}/function.zip"
}

# Upload zipped function
resource "aws_s3_object" "zipped_lambda" {
  bucket = aws_s3_bucket.data_log.id
  key    = "function.zip"
  source = data.archive_file.zipped_lambda.output_path

  etag = filemd5(data.archive_file.zipped_lambda.output_path)
}

# Create the Lambda function
resource "aws_lambda_function" "my_data_lambda" {
  function_name = "my_data_vis_func"
  s3_bucket     = aws_s3_bucket.data_log.id
  s3_key        = aws_s3_object.zipped_lambda.key

  runtime = "python3.9"
  handler = "main_lambda.lambda_handler"

  source_code_hash = data.archive_file.zipped_lambda.output_base64sha256

  role = aws_iam_role.data_vis_db_role.arn
}

# issue start here
# Create an API Gateway REST API
resource "aws_api_gateway_rest_api" "data_vis_api" {
  name        = "data_vis_myrestapi"
  description = "This is an REST API for data visualization"
}

# Create an API Gateway resource
resource "aws_api_gateway_resource" "resource_api" {
  rest_api_id = aws_api_gateway_rest_api.data_vis_api.id
  parent_id   = aws_api_gateway_rest_api.data_vis_api.root_resource_id
  path_part   = "data"
}

# Create a GET method for the API Gateway resource
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.data_vis_api.id
  resource_id   = aws_api_gateway_resource.resource_api.id
  http_method   = "GET"
  authorization = "NONE"
}

# Create a method response for the GET method
resource "aws_api_gateway_method_response" "response_get" {
  rest_api_id = aws_api_gateway_rest_api.data_vis_api.id
  resource_id = aws_api_gateway_resource.resource_api.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# Create an integration for the API Gateway method
resource "aws_api_gateway_integration" "integration_api" {
  rest_api_id             = aws_api_gateway_rest_api.data_vis_api.id
  resource_id             = aws_api_gateway_resource.resource_api.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_data_lambda.invoke_arn
}

# Create an integration response for the API Gateway integration
resource "aws_api_gateway_integration_response" "integration_resp" {
  rest_api_id = aws_api_gateway_rest_api.data_vis_api.id
  resource_id = aws_api_gateway_resource.resource_api.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"

  depends_on = [aws_api_gateway_integration.integration_api]
}

# Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_data_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_api_gateway_rest_api.data_vis_api.execution_arn
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.integration_api]
  rest_api_id = aws_api_gateway_rest_api.data_vis_api.id

  stage_name = "dev"
}

# Output the Lambda function ARN
output "lambda_function_arn" {
  value = aws_lambda_function.my_data_lambda.arn
}

# Output the API Gateway invoke URL
output "api_invoke_url" {
  value = aws_api_gateway_deployment.api_deployment.invoke_url
}

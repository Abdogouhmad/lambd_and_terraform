# Output the Lambda function ARN
output "lambda_function_arn" {
  value = aws_lambda_function.my_data_lambda.arn
}

# Output the API Gateway invoke URL
output "api_invoke_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/data"
}

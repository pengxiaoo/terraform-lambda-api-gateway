terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

data "archive_file" "lambda_docdb_retriever" {
  type        = "zip"
  source_file = "${path.module}/lambda-docdb-retriever/lambda.py"
  output_path = "lambda.py.zip"
}

resource "aws_lambda_function" "docdb_retriever" {
  function_name    = "lambda_docdb_retriever"
  filename         = "lambda.py.zip"
  runtime          = "python3.9"
  handler          = "lambda.lambda_handler"
  layers           = [var.aws_lambda_layer]
  source_code_hash = data.archive_file.lambda_docdb_retriever.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 60
  environment {
    variables = {
      MONGO_USER            = "alex"
      MONGO_PWD             = "sS509509"
      MONGO_DATABASE        = "openapi"
      MONGO_COL_ACTIONS     = "actions"
      MONGO_COL_OPERATIONS  = "operations"
      MONGO_HOST_AND_PARAMS = "docdb-alex-2022-11-16.cluster-cdpgg8pexphe.us-west-2.docdb.amazonaws.com:27017/?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
    }
  }
  vpc_config {
    subnet_ids         = ["subnet-0ac6cd9c871c536d8", "subnet-026aa030d347949b3"]
    security_group_ids = ["sg-029bce67"]
  }
}

resource "aws_cloudwatch_log_group" "docdb_retriever" {
  name              = "/aws/lambda/${aws_lambda_function.docdb_retriever.function_name}"
  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    }
    )
  }
}

resource "aws_apigatewayv2_integration" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id
  integration_uri    = aws_lambda_function.docdb_retriever.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.docdb_retriever.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

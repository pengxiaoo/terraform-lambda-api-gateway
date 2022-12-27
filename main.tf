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
  output_path = "${path.module}/lambda-docdb-retriever/lambda.py.zip"
}

resource "aws_lambda_function" "docdb_retriever" {
  function_name    = "lambda_docdb_retriever"
  filename         = "${path.module}/lambda-docdb-retriever/lambda.py.zip"
  runtime          = "python3.9"
  handler          = "lambda.lambda_handler"
  layers           = [var.aws_lambda_layer]
  source_code_hash = data.archive_file.lambda_docdb_retriever.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 60
  environment {
    variables = {
      MONGO_USER            = var.aws_lambda_env_variables.MONGO_USER
      MONGO_PWD             = var.aws_lambda_env_variables.MONGO_PWD
      MONGO_DATABASE        = var.aws_lambda_env_variables.MONGO_DATABASE
      MONGO_COL_ACTIONS     = var.aws_lambda_env_variables.MONGO_COL_ACTIONS
      MONGO_COL_OPERATIONS  = var.aws_lambda_env_variables.MONGO_COL_OPERATIONS
      MONGO_HOST_AND_PARAMS = var.aws_lambda_env_variables.MONGO_HOST_AND_PARAMS
    }
  }
  vpc_config {
    subnet_ids         = [var.aws_lambda_vpc_config.subnet_id_1, var.aws_lambda_vpc_config.subnet_id_2]
    security_group_ids = [var.aws_lambda_vpc_config.security_group_id_1]
  }
}

resource "aws_cloudwatch_log_group" "docdb_retriever" {
  name              = "/aws/lambda/${aws_lambda_function.docdb_retriever.function_name}"
  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name               = "docdb_retriever_role"
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
  name          = "api-docdb-retriever"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "authorizer" {
  api_id           = aws_apigatewayv2_api.lambda.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "daywaa-authorizer"
  jwt_configuration {
    audience = [var.daywaa_auth0_authorizer.audience]
    issuer   = var.daywaa_auth0_authorizer.issuer
  }
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.lambda.id
  name        = "v1"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format          = jsonencode({
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

resource "aws_apigatewayv2_integration" "integration" {
  api_id             = aws_apigatewayv2_api.lambda.id
  integration_uri    = aws_lambda_function.docdb_retriever.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "route_actions" {
  api_id             = aws_apigatewayv2_api.lambda.id
  route_key          = "GET /actions"
  target             = "integrations/${aws_apigatewayv2_integration.integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.authorizer.id
}

resource "aws_apigatewayv2_route" "route_operations" {
  api_id             = aws_apigatewayv2_api.lambda.id
  route_key          = "GET /operations"
  target             = "integrations/${aws_apigatewayv2_integration.integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.authorizer.id
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.docdb_retriever.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

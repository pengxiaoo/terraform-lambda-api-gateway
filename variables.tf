# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."
  type    = string
  default = "us-west-2"
}

variable "aws_lambda_layer" {
  type = string
  default = "arn:aws:lambda:us-west-2:422535705451:layer:pymongo-json-ref-layer:1"
}
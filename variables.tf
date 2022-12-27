# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-west-2"
}

variable "aws_lambda_layer" {
  type    = string
  default = "arn:aws:lambda:us-west-2:422535705451:layer:pymongo-json-ref-layer:1"
}

variable "aws_lambda_env_variables" {
  type    = map(string)
  default = {
    "MONGO_USER"            = "alex"
    "MONGO_PWD"             = "sS509509"
    "MONGO_DATABASE"        = "openapi"
    "MONGO_COL_ACTIONS"     = "actions"
    "MONGO_COL_OPERATIONS"  = "operations"
    "MONGO_HOST_AND_PARAMS" = "docdb-alex-2022-11-16.cluster-cdpgg8pexphe.us-west-2.docdb.amazonaws.com:27017/?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  }
}

variable "aws_lambda_vpc_config" {
  type    = map(string)
  default = {
    "subnet_id_1"         = "subnet-0ac6cd9c871c536d8"
    "subnet_id_2"         = "subnet-026aa030d347949b3"
    "security_group_id_1" = "sg-029bce67"
  }
}

variable "daywaa_auth0_authorizer" {
  type    = map(string)
  default = {
    "issuer"   = "https://daywaa.au.auth0.com/"
    "audience" = "https://daywaa-auth0-authorizer"
  }
}
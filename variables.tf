# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_lambda_layer" {
  type    = string
  default = ""
}

variable "aws_lambda_env_variables" {
  type    = map(string)
  default = {
    "MONGO_USER"            = ""
    "MONGO_PWD"             = ""
    "MONGO_DATABASE"        = ""
    "MONGO_COL_ACTIONS"     = ""
    "MONGO_COL_OPERATIONS"  = ""
    "MONGO_HOST_AND_PARAMS" = ""
  }
}

variable "aws_lambda_vpc_config" {
  type    = map(string)
  default = {
    "subnet_id_1"         = ""
    "subnet_id_2"         = ""
    "security_group_id_1" = ""
  }
}

variable "daywaa_auth0_authorizer" {
  type    = map(string)
  default = {
    "issuer"   = ""
    "audience" = ""
  }
}
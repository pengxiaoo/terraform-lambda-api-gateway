### reference

I followed the official tutorial https://developer.hashicorp.com/terraform/tutorials/aws/lambda-api-gateway. It maybe
not the best practice since it is a tutorial for beginners.

### requirements

install terraform https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

install aws cli

setup aws configure. the aws account should have access to lambda, api gateway, iam, cloudwatch

customize variables.tf
### cmds

terraform init

terraform apply --auto-approve
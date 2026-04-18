terraform {
  required_version = ">= 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "emr-terraform-state-736822756246"
    key            = "prod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "emr-terraform-locks"
    encrypt        = true
  }
}

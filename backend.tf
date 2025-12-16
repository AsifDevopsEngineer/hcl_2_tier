
terraform {
  required_version = ">= 1.3.0"

  backend "s3" {
    bucket         = "my-demo-bucket-asif"          # Your S3 bucket name
    key            = "envs/dev/network/terraform.tfstate" # Path for state file in S3
    region         = "ap-south-1"                   # AWS region
    dynamodb_table = "my-demo-table-asif"           # DynamoDB table for state locking
    encrypt        = true                           # Enable server-side encryption
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

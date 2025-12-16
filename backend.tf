
terraform {


  backend "s3" {
    bucket         = "my-demo-bucket-asif"          # Your S3 bucket name
    key            = "envs/dev/network/terraform.tfstate" # Path for state file in S3
    region         = "ap-south-1"                   # AWS region
    dynamodb_table = "my-demo-table-asif"           # DynamoDB table for state locking
    encrypt        = true                           # Enable server-side encryption
  }
}




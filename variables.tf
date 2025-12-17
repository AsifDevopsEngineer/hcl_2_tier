variable "aws_region" {
  default = "ap-south-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  default = "t2.micro"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  description = "RDS MySQL password"
  type        = string
  sensitive   = true
  default     = "StrongPassword123!"
}

variable "db_name" {
  default = "appdb"
}

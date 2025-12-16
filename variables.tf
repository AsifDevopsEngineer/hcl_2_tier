
variable "project" {
  description = "Project or environment name used for tagging."
  type        = string
  default     = "web-db"
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1" // Hyderabad users often choose Mumbai; change if needed
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of two availability zones."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (2)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (2)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (lower cost) vs one per AZ."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to resources."
  type        = map(string)
  default = {
    Owner       = "Asif Shaik"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

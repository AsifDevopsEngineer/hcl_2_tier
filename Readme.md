1. Define Architecture

A 2-tier architecture:

Web Tier → EC2 instances in public subnets.
Database Tier → RDS MySQL in private subnets.


Ensure high availability by using multiple Availability Zones.


2. Create Custom VPC

Design a VPC with a CIDR block (e.g., 10.0.0.0/16).
Enable DNS support and hostnames.


3. Create Subnets

Public Subnets for Web Tier (2 subnets in different AZs).
Private Subnets for Database Tier (2 subnets in different AZs).


4. Configure Internet 

Attach Internet Gateway for public subnets.



5. Set Up Route Tables

Public Route Table → Routes to Internet Gateway.



6. Launch EC2 Instances (Web Tier)

Deploy EC2 instances in public subnets.
Install Apache using user_data.
Configure Security Group: Allow HTTP (80) and SSH (22).


7. Deploy RDS MySQL (Database Tier)

Create RDS MySQL in private subnets.
Enable Multi-AZ for high availability.
Configure Security Group: Allow MySQL (3306) only from Web Tier SG.


8. Configure Remote State

Create S3 bucket for Terraform state storage.
Create DynamoDB table for state locking.


9. Provision Resources Using Terraform

Write Terraform scripts for VPC, EC2, RDS, and networking.
Initialize and apply Terraform:
Shellterraform initterraform planterraform applyShow more lines



10. Set Up GitHub Actions Workflow

Create a workflow file to:

Checkout code
Setup Terraform
Run terraform init and plan on push to main.

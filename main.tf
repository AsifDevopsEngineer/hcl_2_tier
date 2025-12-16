
locals {
  name_prefix = var.project
  common_tags = merge(var.tags, { Project = var.project })
}

# ---------------------------
# VPC
# ---------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# Internet Gateway for public egress
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ---------------------------
# Subnets
# ---------------------------

# Public subnets (Web Tier)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

# Private subnets (DB Tier)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}

# ---------------------------
# NAT Gateway (for private subnets to reach Internet securely)
# ---------------------------

# Allocate EIP for NAT (only one in single_nat_gateway mode)
resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : 2
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
}

# NAT Gateway(s) placed in public subnets
resource "aws_nat_gateway" "nat" {
  count         = var.single_nat_gateway ? 1 : 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.igw]
}

# ---------------------------
# Route Tables & Associations
# ---------------------------

# Public route table: default route to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rt-public"
  })
}

# Associate public subnets to public route table
resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables:
# If single NAT, one route table for both private subnets.
# If multi NAT, create one route table per AZ and route to the corresponding NAT.
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : 2
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = [0]
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rt-private-${count.index + 1}"
  })
}

# Associate private subnets to private route tables
# If single NAT, both subnets associate to the single private route table.
# If multi NAT, associate each subnet to its AZ's private route table.
resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}



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


# -------------------------------------------------------
# Security Groups
# -------------------------------------------------------

# ALB Security Group: allows inbound HTTP/HTTPS from allowed CIDRs, outbound to web tier
resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  # HTTP ingress
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  # Optional HTTPS ingress
  dynamic "ingress" {
    for_each = var.alb_enable_https ? [1] : []
    content {
      description = "Allow HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_ingress_cidrs
    }
  }

  # ALB egress to web SG
  egress {
    description     = "Allow outbound to web servers"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.web_sg.id]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

# Web Server Security Group: allows inbound from ALB only
resource "aws_security_group" "web_sg" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web/app servers behind ALB"
  vpc_id      = aws_vpc.main.id

  # Inbound from ALB on app port
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.web_target_port
    to_port         = var.web_target_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Egress to anywhere (or restrict to needed destinations)
  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web-sg" })
}

# -------------------------------------------------------
# Target Group (HTTP)
# -------------------------------------------------------
resource "aws_lb_target_group" "web_tg" {
  name        = "${local.name_prefix}-tg"
  port        = var.web_target_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # or "ip" if using ECS Fargate/etc.

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-tg" })
}

# -------------------------------------------------------
# Application Load Balancer
# -------------------------------------------------------
resource "aws_lb" "alb" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(local.common_tags, { Name = var.alb_name })
}

# -------------------------------------------------------
# Listeners
# -------------------------------------------------------

# HTTP Listener -> forwards to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Optional HTTPS Listener (requires ACM certificate in the same region)
resource "aws_lb_listener" "https" {
  count             = var.alb_enable_https ? 1 : 0
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# -------------------------------------------------------
# (Example) Register existing instances to the target group
# -------------------------------------------------------
# If you already have EC2 instances (e.g., created elsewhere), you can attach them:
# resource "aws_lb_target_group_attachment" "example" {
#   count            = length(var.instance_ids)
#   target_group_arn = aws_lb_target_group.web_tg.arn
#   target_id        = var.instance_ids[count.index]
#   port             = var.web_target_port
# }
#
# Alternatively, if you're using an Auto Scaling Group, attach the target group there:
# resource "aws_autoscaling_attachment" "asg_alb" {
#   autoscaling_group_name = aws_autoscaling_group.web_asg.name
#   alb_target_group_arn   = aws_lb_target_group.web_tg.arn
# }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = var.project_name
    }
  }
}

# Network

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# DHCP Options
resource "aws_vpc_dhcp_options" "dhcp_options" {
  domain_name         = var.region == "us-east-1" ? "ec2.internal" : "${var.region}.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
}

# IGW
resource "aws_internet_gateway" "internet_gateway" {
  depends_on = [aws_vpc.vpc]
}

# IGW-VPC
resource "aws_internet_gateway_attachment" "internet_gateway_attachment" {
  depends_on          = [aws_internet_gateway.internet_gateway]
  internet_gateway_id = aws_internet_gateway.internet_gateway.id
  vpc_id              = aws_vpc.vpc.id
}

# Public RT
resource "aws_route_table" "public_route_table" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id
}

# Public Route (through IGW)
resource "aws_route" "public_route" {
  depends_on             = [aws_route_table.public_route_table, aws_internet_gateway_attachment.internet_gateway_attachment]
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

data "aws_availability_zones" "azs" {
  state = "available"
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  depends_on        = [aws_route_table.public_route_table]
  count             = min(length(data.aws_availability_zones.azs.names), 3)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

resource "aws_route_table_association" "public_subnet_rt_assoc" {
  depends_on     = [aws_subnet.public_subnet]
  count          = length(aws_subnet.public_subnet.*.id)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}

# # EIP for NATGW
# resource "aws_eip" "eip" {
#   domain = "vpc"
# }

# # NATGW
# resource "aws_nat_gateway" "nat_gateway" {
#   depends_on    = [aws_eip.eip, aws_subnet.public_subnet.1]
#   allocation_id = aws_eip.eip.allocation_id
#   subnet_id     = aws_subnet.public_subnet.1.id
# }

# Private RT
resource "aws_route_table" "private_route_table" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id
}

# VPC endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api_vpc_endpoint" {
  depends_on          = [aws_subnet.private_subnet, aws_subnet.private_subnet]
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_subnet.*.id
  security_group_ids  = [aws_security_group.ecs_sg.id]
}

# VPC endpoint for ECR docker registry API
resource "aws_vpc_endpoint" "ecr_dkr_vpc_endpoint" {
  depends_on          = [aws_security_group.ecs_sg, aws_subnet.private_subnet]
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_subnet.*.id
  security_group_ids  = [aws_security_group.ecs_sg.id]
}

# VPC endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "ecr_cloudwatch_vpc_endpoint" {
  depends_on          = [aws_security_group.ecs_sg, aws_subnet.private_subnet]
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_subnet.*.id
  security_group_ids  = [aws_security_group.ecs_sg.id]
}

# VPC endpoint for ECR S3
resource "aws_vpc_endpoint" "ecr_s3_vpc_endpoint" {
  depends_on        = [aws_route_table.private_route_table]
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_route_table.id]
}

# Private Subnets
resource "aws_subnet" "private_subnet" {
  depends_on        = [aws_route_table.private_route_table, aws_subnet.public_subnet]
  count             = min(length(data.aws_availability_zones.azs.names), 3)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.${length(aws_subnet.public_subnet.*.id) + count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

resource "aws_route_table_association" "private_subnet_rt_assoc" {
  depends_on     = [aws_subnet.private_subnet]
  count          = length(aws_subnet.private_subnet.*.id)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_route_table.id
}

# ECR Repo
resource "aws_ecr_repository" "ecr_repo" {
  name                 = var.project_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}
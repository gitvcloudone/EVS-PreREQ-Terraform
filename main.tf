# 1. Create VPC
resource "aws_vpc" "evs_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "evs-vpc" }
}

# 2. Service Access Subnet
resource "aws_subnet" "service_access" {
  vpc_id            = aws_vpc.evs_vpc.id
  cidr_block        = var.service_access_cidr
  availability_zone = var.az
  tags = { Name = "evs-service-access-a" }
}

# 3. Security Group for Resolver
resource "aws_security_group" "dns_sg" {
  name        = "evs-dns-sg"
  description = "Allow DNS for EVS"
  vpc_id      = aws_vpc.evs_vpc.id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

# 4. Route 53 Resolver Endpoint
resource "aws_route53_resolver_endpoint" "evs_dns" {
  name      = "evs-dns-resolver"
  direction = "INBOUND"
  security_group_ids = [aws_security_group.dns_sg.id]

  ip_address {
    subnet_id = aws_subnet.service_access.id
    ip        = "10.0.1.110"
  }
  ip_address {
    subnet_id = aws_subnet.service_access.id
    ip        = "10.0.1.100"
  }
}

# 5. DHCP Options Set
resource "aws_vpc_dhcp_options" "evs_dhcp" {
  domain_name         = var.domain_name
  domain_name_servers = [for ip in aws_route53_resolver_endpoint.evs_dns.ip_address : ip.ip]
  ntp_servers         = ["169.254.169.123"]
  tags = { Name = "evs-dhcp-options-automated" }
}

resource "aws_vpc_dhcp_options_association" "evs_vpc_dhcp" {
  vpc_id          = aws_vpc.evs_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.evs_dhcp.id
}

# 6. Service-Linked Role
resource "aws_iam_service_linked_role" "evs" {
  aws_service_name = "evs.amazonaws.com"
}

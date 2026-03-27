# ── Phase 3: VPC ─────────────────────────────────────────────────────────────

resource "aws_vpc" "evs_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "evs-vpc" }
}

# ── Phase 6: Service Access Subnet & Route Table ──────────────────────────────
# This is the only subnet pre-created by the user. All 10 VLAN subnets are
# automatically provisioned by EVS during bring-up.

resource "aws_subnet" "service_access" {
  vpc_id            = aws_vpc.evs_vpc.id
  cidr_block        = var.service_access_cidr
  availability_zone = var.az
  tags = { Name = "evs-service-access" }
}

# A dedicated route table with an explicit subnet association is required.
# Propagated route tables without explicit associations silently fail to
# receive BGP routes from the Route Server.
resource "aws_route_table" "service_access" {
  vpc_id = aws_vpc.evs_vpc.id
  tags   = { Name = "evs-service-access-rt" }
}

resource "aws_route_table_association" "service_access" {
  subnet_id      = aws_subnet.service_access.id
  route_table_id = aws_route_table.service_access.id
}

# ── Phase 4: Security Group for DNS Resolver ──────────────────────────────────

resource "aws_security_group" "dns_sg" {
  name        = "evs-dns-sg"
  description = "Allow inbound DNS from VPC CIDR to Route 53 Resolver endpoints"
  vpc_id      = aws_vpc.evs_vpc.id

  ingress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "evs-dns-sg" }
}

# ── Phase 7: Network ACL for BGP (TCP 179) ────────────────────────────────────
# NACLs are stateless — both directions must be explicitly permitted.
# The NSX Uplink VLAN CIDR (default 10.0.16.0/24) must be able to reach
# the Route Server endpoints in the Service Access Subnet on TCP 179.

resource "aws_network_acl" "service_access" {
  vpc_id     = aws_vpc.evs_vpc.id
  subnet_ids = [aws_subnet.service_access.id]
  tags       = { Name = "evs-service-access-nacl" }

  # Allow all inbound from VPC (covers DNS 53, BGP 179, ephemeral ports)
  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound to VPC
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }
}

# ── Phase 4: Route 53 Inbound Resolver Endpoints ─────────────────────────────
# Two separate ENIs with dedicated IPs in the Service Access Subnet.
# Both IPs become the primary and secondary DNS servers in the DHCP Options Set.
# Using explicit IPs (not dynamic lookup) ensures stable, ordered DNS configuration.

resource "aws_route53_resolver_endpoint" "evs_dns_1" {
  name               = "evs-dns-resolver-1"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.dns_sg.id]

  ip_address {
    subnet_id = aws_subnet.service_access.id
    ip        = var.resolver_ip_1
  }

  tags = { Name = "evs-dns-resolver-1" }
}

resource "aws_route53_resolver_endpoint" "evs_dns_2" {
  name               = "evs-dns-resolver-2"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.dns_sg.id]

  ip_address {
    subnet_id = aws_subnet.service_access.id
    ip        = var.resolver_ip_2
  }

  tags = { Name = "evs-dns-resolver-2" }
}

# ── Phase 5: DHCP Options Set ─────────────────────────────────────────────────
# domain_name must exactly match the Route 53 private hosted zone name.
# domain_name_servers must list the two resolver IPs — primary first.
# ntp_servers uses the AWS Time Sync Service (link-local, no internet required).

resource "aws_vpc_dhcp_options" "evs_dhcp" {
  domain_name         = var.domain_name
  domain_name_servers = [var.resolver_ip_1, var.resolver_ip_2]
  ntp_servers         = ["169.254.169.123"]
  tags                = { Name = "evs-dhcp-options" }
}

resource "aws_vpc_dhcp_options_association" "evs_vpc_dhcp" {
  vpc_id          = aws_vpc.evs_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.evs_dhcp.id
}

# ── Phase 2: IAM Service-Linked Role ─────────────────────────────────────────
# Allows the EVS service to create and manage EC2, networking, and Secrets
# Manager resources on your behalf. Created automatically on first EVS operation
# but provisioning it via Terraform ensures it exists before CreateEnvironment.

resource "aws_iam_service_linked_role" "evs" {
  aws_service_name = "evs.amazonaws.com"
}


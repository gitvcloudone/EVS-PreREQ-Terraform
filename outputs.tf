# ── VPC & Networking ──────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the EVS VPC."
  value       = aws_vpc.evs_vpc.id
}

output "service_access_subnet_id" {
  description = "ID of the Service Access Subnet."
  value       = aws_subnet.service_access.id
}

output "service_access_route_table_id" {
  description = "ID of the explicitly associated route table for the Service Access Subnet. Used for Route Server propagation."
  value       = aws_route_table.service_access.id
}

# ── DNS ───────────────────────────────────────────────────────────────────────

output "resolver_primary_ip" {
  description = "IP of Route 53 Resolver inbound endpoint #1. Used as the primary domain-name-server in the DHCP Options Set."
  value       = var.resolver_ip_1
}

output "resolver_secondary_ip" {
  description = "IP of Route 53 Resolver inbound endpoint #2. Used as the secondary domain-name-server in the DHCP Options Set."
  value       = var.resolver_ip_2
}

output "private_hosted_zone_id" {
  description = "Route 53 private hosted zone ID."
  value       = aws_route53_zone.forward.zone_id
}

output "dhcp_options_id" {
  description = "ID of the DHCP Options Set associated with the EVS VPC."
  value       = aws_vpc_dhcp_options.evs_dhcp.id
}

# ── Route Server ──────────────────────────────────────────────────────────────

output "route_server_id" {
  description = "ID of the VPC Route Server."
  value       = aws_vpc_route_server.evs_rs.route_server_id
}

output "route_server_endpoint_1_id" {
  description = "ID of Route Server endpoint 1. EVS uses this endpoint's IP as a BGP neighbor when auto-configuring NSX Tier-0."
  value       = aws_vpc_route_server_endpoint.ep1.route_server_endpoint_id
}

output "route_server_endpoint_2_id" {
  description = "ID of Route Server endpoint 2. EVS uses this endpoint's IP as a BGP neighbor when auto-configuring NSX Tier-0."
  value       = aws_vpc_route_server_endpoint.ep2.route_server_endpoint_id
}


# ── IAM ───────────────────────────────────────────────────────────────────────

output "evs_deploy_policy_arn" {
  description = "ARN of the IAM policy to attach to the user or role that will create the EVS environment."
  value       = aws_iam_policy.evs_deploy.arn
}

output "evs_service_linked_role_arn" {
  description = "ARN of the EVS service-linked role."
  value       = aws_iam_service_linked_role.evs.arn
}

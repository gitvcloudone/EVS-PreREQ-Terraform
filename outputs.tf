output "vpc_id" {
  value = aws_vpc.evs_vpc.id
}

output "subnet_id" {
  value = aws_subnet.service_access.id
}

output "route_server_id" {
  value = aws_vpc_route_server.evs_rs.route_server_id
}

output "resolver_ips" {
  value = [for ip in aws_route53_resolver_endpoint.evs_dns.ip_address : ip.ip]
}

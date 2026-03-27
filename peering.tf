# VPC Route Server
resource "aws_vpc_route_server" "evs_rs" {
  amazon_side_asn = 64512
  tags            = { Name = "evs-route-server" }
}

resource "aws_vpc_route_server_vpc_association" "evs_rs_vpc" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  vpc_id          = aws_vpc.evs_vpc.id
}

# Route Server Endpoints
resource "aws_vpc_route_server_endpoint" "ep1" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  subnet_id       = aws_subnet.service_access.id
}

resource "aws_vpc_route_server_endpoint" "ep2" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  subnet_id       = aws_subnet.service_access.id
}

# BGP Peering
resource "aws_vpc_route_server_peer" "edge_01" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.ep1.route_server_endpoint_id
  peer_address             = var.nsx_edges["edge-01"]
  bgp_options {
    peer_asn               = 65000
    peer_liveness_detection = "bgp-keepalive"
  }
}

resource "aws_vpc_route_server_peer" "edge_02" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.ep2.route_server_endpoint_id
  peer_address             = var.nsx_edges["edge-02"]
  bgp_options {
    peer_asn               = 65000
    peer_liveness_detection = "bgp-keepalive"
  }
}

# Propagation
resource "aws_vpc_route_server_propagation" "main_rt" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  route_table_id  = aws_vpc.evs_vpc.main_route_table_id

  depends_on = [aws_vpc_route_server_vpc_association.evs_rs_vpc]
}

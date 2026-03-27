# ── Phase 7: VPC Route Server ─────────────────────────────────────────────────
# The Route Server is the BGP bridge between the AWS VPC and NSX overlay.
# NSX Tier-0 BGP neighbors are auto-configured by EVS during bring-up using
# the endpoint IPs below — no manual NSX configuration is required.

resource "aws_vpc_route_server" "evs_rs" {
  amazon_side_asn         = var.route_server_asn
  persist_routes          = "enable"
  persist_routes_duration = 2 # minutes to hold routes after BGP session drops
  tags                    = { Name = "evs-route-server" }
}

resource "aws_vpc_route_server_vpc_association" "evs_rs_vpc" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  vpc_id          = aws_vpc.evs_vpc.id
}

# ── Route Server Endpoints ────────────────────────────────────────────────────
# Two endpoints are deployed into the Service Access Subnet.
# EVS uses the endpoint IPs as BGP neighbor addresses when auto-configuring NSX.

resource "aws_vpc_route_server_endpoint" "ep1" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  subnet_id       = aws_subnet.service_access.id

  depends_on = [aws_vpc_route_server_vpc_association.evs_rs_vpc]
}

resource "aws_vpc_route_server_endpoint" "ep2" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  subnet_id       = aws_subnet.service_access.id

  depends_on = [aws_vpc_route_server_vpc_association.evs_rs_vpc]
}

# ── BGP Peers ─────────────────────────────────────────────────────────────────
# Peer addresses are NSX Edge uplink IPs from the NSX Uplink VLAN (10.0.16.x).
# These IPs are assigned to NSX Edge appliances during EVS bring-up.
# peer_asn must match the NSX Tier-0 local AS (nsx_peer_asn variable, default 65000).
# Always use bgp-keepalive — BFD is not supported for Amazon EVS.

resource "aws_vpc_route_server_peer" "edge_01" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.ep1.route_server_endpoint_id
  peer_address             = var.nsx_edge_peer_ips["edge-01"]
  bgp_options {
    peer_asn                = var.nsx_peer_asn
    peer_liveness_detection = "bgp-keepalive"
  }
  tags = { Name = "evs-bgp-peer-edge-01" }
}

resource "aws_vpc_route_server_peer" "edge_02" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.ep2.route_server_endpoint_id
  peer_address             = var.nsx_edge_peer_ips["edge-02"]
  bgp_options {
    peer_asn                = var.nsx_peer_asn
    peer_liveness_detection = "bgp-keepalive"
  }
  tags = { Name = "evs-bgp-peer-edge-02" }
}

# ── Route Propagation ─────────────────────────────────────────────────────────
# Propagates NSX overlay routes into the Service Access Subnet route table.
# Uses the explicitly associated route table (not the VPC main route table).
# IMPORTANT: Any route table configured for propagation must have an explicit
# subnet association or BGP routes will silently fail to appear.

resource "aws_vpc_route_server_propagation" "service_access_rt" {
  route_server_id = aws_vpc_route_server.evs_rs.route_server_id
  route_table_id  = aws_route_table.service_access.id

  depends_on = [
    aws_vpc_route_server_vpc_association.evs_rs_vpc,
    aws_route_table_association.service_access,
  ]
}

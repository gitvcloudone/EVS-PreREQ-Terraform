# ── Phase 4: Route 53 Private Hosted Zone ────────────────────────────────────

resource "aws_route53_zone" "forward" {
  name = var.domain_name
  vpc {
    vpc_id = aws_vpc.evs_vpc.id
  }
  tags = { Name = "evs-forward-zone" }
}

# ── Reverse Lookup Zones ──────────────────────────────────────────────────────
# Zone names are driven by variables so changing IP subnets stays consistent.
# Host Management VLAN (default 10.0.10.0/24) — ESXi hosts
resource "aws_route53_zone" "host_mgmt_reverse" {
  name = var.host_mgmt_reverse_zone
  vpc { vpc_id = aws_vpc.evs_vpc.id }
  tags = { Name = "evs-host-mgmt-reverse" }
}

# Management VM VLAN (default 10.0.11.0/24) — vCenter, SDDC Mgr, NSX, Edges
resource "aws_route53_zone" "mgmt_vm_reverse" {
  name = var.mgmt_vm_reverse_zone
  vpc { vpc_id = aws_vpc.evs_vpc.id }
  tags = { Name = "evs-mgmt-vm-reverse" }
}

# ── VCF Appliance A Records (Management VM VLAN — 10.0.11.x) ─────────────────
# Covers: cloud-builder, sddc-manager, vcenter, nsx-mgr-01/02/03,
#         nsx-edge-01/02. All must exist before EVS bring-up.

resource "aws_route53_record" "vcf_a" {
  for_each = var.vcf_components
  zone_id  = aws_route53_zone.forward.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"
  ttl      = 300
  records  = [each.value]
}

# ── VCF Appliance PTR Records (Management VM VLAN — 11.0.10.in-addr.arpa) ────
# Extracts the last octet of the IP for the PTR record name.
# e.g. 10.0.11.12 -> "12" in zone "11.0.10.in-addr.arpa"

resource "aws_route53_record" "vcf_ptr" {
  for_each = var.vcf_components
  zone_id  = aws_route53_zone.mgmt_vm_reverse.zone_id
  name     = element(split(".", each.value), 3)
  type     = "PTR"
  ttl      = 300
  records  = ["${each.key}.${var.domain_name}."]
}

# ── ESXi Host A Records (Host Management VLAN — 10.0.10.x) ───────────────────

resource "aws_route53_record" "esxi_a" {
  for_each = var.esxi_hosts
  zone_id  = aws_route53_zone.forward.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"
  ttl      = 300
  records  = [each.value]
}

# ── ESXi Host PTR Records (Host Management VLAN — 10.0.10.in-addr.arpa) ──────
# e.g. 10.0.10.21 -> "21" in zone "10.0.10.in-addr.arpa"

resource "aws_route53_record" "esxi_ptr" {
  for_each = var.esxi_hosts
  zone_id  = aws_route53_zone.host_mgmt_reverse.zone_id
  name     = element(split(".", each.value), 3)
  type     = "PTR"
  ttl      = 300
  records  = ["${each.key}.${var.domain_name}."]
}

# Forward Zone
resource "aws_route53_zone" "forward" {
  name = var.domain_name
  vpc {
    vpc_id = aws_vpc.evs_vpc.id
  }
}

# Reverse Zones
resource "aws_route53_zone" "mgmt_reverse" {
  name = "10.0.10.in-addr.arpa"
  vpc { vpc_id = aws_vpc.evs_vpc.id }
}

resource "aws_route53_zone" "host_reverse" {
  name = "11.0.10.in-addr.arpa"
  vpc { vpc_id = aws_vpc.evs_vpc.id }
}

# A Records for Components
resource "aws_route53_record" "vcf_a" {
  for_each = var.vcf_components
  zone_id  = aws_route53_zone.forward.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"
  ttl      = "300"
  records  = [each.value]
}

# PTR Records for Components
resource "aws_route53_record" "vcf_ptr" {
  for_each = var.vcf_components
  zone_id  = aws_route53_zone.mgmt_reverse.zone_id
  # Extracts last octet from e.g. 10.0.10.12 -> 12
  name     = "${element(split(".", each.value), 3)}.10.0.10.in-addr.arpa."
  type     = "PTR"
  ttl      = "300"
  records  = ["${each.key}.${var.domain_name}."]
}

# A Records for ESXi
resource "aws_route53_record" "esxi_a" {
  for_each = var.esxi_hosts
  zone_id  = aws_route53_zone.forward.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"
  ttl      = "300"
  records  = [each.value]
}

# PTR Records for ESXi
resource "aws_route53_record" "esxi_ptr" {
  for_each = var.esxi_hosts
  zone_id  = aws_route53_zone.host_reverse.zone_id
  name     = "${element(split(".", each.value), 3)}.11.0.10.in-addr.arpa."
  type     = "PTR"
  ttl      = "300"
  records  = ["${each.key}.${var.domain_name}."]
}

# EVS-PreREQ-Terraform

Terraform automation for Amazon EVS (Elastic VMware Service) prerequisites. Deploys all required AWS infrastructure for Steps 2, 4–7 of the EVS readiness guide so you can run `CreateEnvironment` without manual console steps. Step 3 (IP Address Planning) is a planning exercise — no resources are created.

## Prerequisites (Step 1 — manual)

Before applying this Terraform, complete Step 1 manually in the AWS console or CLI:

- Enroll in **AWS Business Support** or higher (environment creation fails without it)
- Obtain a valid **VCF Solution Key** (minimum 256 cores for i4i.metal/4-host cluster)
- Obtain a valid **vSAN License Key** (minimum 110 TiB capacity)
- Obtain your **Broadcom Site ID** from Broadcom at contract close/renewal
- If on-premises connectivity is required, provision an **AWS Transit Gateway** — VPC peering, Direct Connect Private VIFs, and VGW-based VPNs are not supported with EVS

These are not automatable via Terraform and must be in place before `CreateEnvironment`.

## What it deploys

| Step | Resource | File |
|-------|----------|------|
| 2 | `AWSServiceRoleForEVS` service-linked role | `main.tf` |
| 2 | `EVSDeploymentPolicy` IAM policy (minimum permissions for `CreateEnvironment`) | `iam.tf` |
| 4 | VPC with `enable_dns_hostnames` and `enable_dns_support` | `main.tf` |
| 4 | Service access subnet with dedicated route table and explicit association | `main.tf` |
| 5 | Route 53 private hosted zone | `dns.tf` |
| 5 | Forward (A) and reverse (PTR) records for all VCF components and ESXi hosts | `dns.tf` |
| 5 | Route 53 inbound resolver endpoint with 2 static IPs | `main.tf` |
| 5 | DNS security group (UDP/TCP 53 from VPC CIDR) | `main.tf` |
| 6 | DHCP options set with domain name, resolver IPs, and NTP (`169.254.169.123`) | `main.tf` |
| 7 | VPC Route Server with `persist_routes = enable` | `peering.tf` |
| 7 | Two Route Server endpoints in the service access subnet | `peering.tf` |
| 7 | Two BGP peers (NSX Edge uplink IPs, `bgp-keepalive` liveness) | `peering.tf` |
| 7 | Route propagation to the explicit route table | `peering.tf` |
| 4 | Network ACL for the service access subnet (DNS + BGP rules) | `main.tf` |
| 8 | On-Demand Capacity Reservation for `i4i.metal` — **commented out** in `odcr.tf` | `odcr.tf` |

## Requirements

- Terraform >= 1.5
- AWS provider >= 5.84 (required for VPC Route Server resources)
- AWS credentials with permissions to create VPC, IAM, Route 53, and EC2 resources

## Quick start

```bash
# 1. Clone
git clone https://github.com/gitvcloudone/EVS-PreREQ-Terraform.git
cd EVS-PreREQ-Terraform

# 2. Edit variables.tf — update region, AZ, CIDRs, domain, IPs, and hostnames
#    (see Variables section below for what to change)

# 3. Initialize
terraform init

# 4. Preview
terraform plan

# 5. Deploy (~45 resources, 3–5 minutes)
terraform apply

# 6. Review outputs
terraform output
```

## File descriptions

| File | Description |
|------|-------------|
| `variables.tf` | All configurable values. **Edit this before applying.** |
| `main.tf` | VPC, service access subnet, route table, Network ACL (DNS + BGP), DNS security group, Route 53 resolver endpoint, DHCP options set, EVS service-linked role |
| `dns.tf` | Route 53 private hosted zone, reverse PTR zones for both VLANs, A and PTR records for all VCF components and ESXi hosts |
| `peering.tf` | VPC Route Server, VPC association, two Route Server endpoints, two BGP peers, route propagation |
| `iam.tf` | `EVSDeploymentPolicy` — minimum IAM policy for the user or role calling `CreateEnvironment` |
| `odcr.tf` | On-Demand Capacity Reservation for `i4i.metal` — all code is commented out. Uncomment when ready. |
| `outputs.tf` | Prints VPC ID, subnet ID, route table ID, resolver IPs, hosted zone ID, Route Server IDs, and IAM ARNs after apply |
| `providers.tf` | Terraform >= 1.5, AWS provider >= 5.84, no remote state |

## Variables

Open `variables.tf` and update these values before running `terraform apply`.

### Region and AZ
```hcl
variable "aws_region" { default = "us-east-1" }  # target AWS region
variable "az"         { default = "us-east-1a" } # all resources in same AZ
```

### VPC and subnet CIDRs
```hcl
variable "vpc_cidr"            { default = "10.0.0.0/16" }  # minimum /22
variable "service_access_cidr" { default = "10.0.0.0/24" }  # hosts resolver ENIs and Route Server endpoints
```

### DNS domain
Must match the Route 53 private hosted zone name exactly and be set in DHCP options.
```hcl
variable "domain_name" { default = "evs.vcloudone.local" }
```

### Resolver IPs
Two static IPs within `service_access_cidr`. These become the DHCP `domain-name-servers`.
```hcl
variable "resolver_ip_1" { default = "10.0.0.10" }  # primary
variable "resolver_ip_2" { default = "10.0.0.11" }  # secondary
```

### BGP ASNs
`route_server_asn` must differ from `nsx_peer_asn` and must be a private ASN — 16-bit range `64512–65534` or 32-bit range `4200000000–4294967294`. Default NSX Tier-0 ASN is 65000.
```hcl
variable "route_server_asn" { default = 65100 }
variable "nsx_peer_asn"     { default = 65000 }
```

### VCF component IPs
Must be in the Management VM VLAN (default `10.0.11.x`). A and PTR records are created for every entry.
```hcl
variable "vcf_components" {
  default = {
    "cloud-builder" = "10.0.11.9"
    "sddc-manager"  = "10.0.11.10"
    "vcenter"       = "10.0.11.11"
    "nsx-mgr-01"    = "10.0.11.12"
    "nsx-mgr-02"    = "10.0.11.13"
    "nsx-mgr-03"    = "10.0.11.14"
    "nsx-edge-01"   = "10.0.11.21"
    "nsx-edge-02"   = "10.0.11.22"
  }
}
```

### ESXi host IPs
Must be in the Host Management VLAN (default `10.0.10.x`). Add or remove entries to match your host count (minimum 4 for EVS).
```hcl
variable "esxi_hosts" {
  default = {
    "esxi-01" = "10.0.10.21"
    "esxi-02" = "10.0.10.22"
    "esxi-03" = "10.0.10.23"
    "esxi-04" = "10.0.10.24"
  }
}
```

### Reverse DNS zone names

These must match the /24 subnet of the IPs in `esxi_hosts` and `vcf_components`. If you change those IP subnets, update these variables too — they are not derived automatically.

```hcl
# Format: third-octet.second-octet.first-octet.in-addr.arpa
variable "host_mgmt_reverse_zone" { default = "10.0.10.in-addr.arpa" }  # matches 10.0.10.0/24
variable "mgmt_vm_reverse_zone"   { default = "11.0.10.in-addr.arpa" }  # matches 10.0.11.0/24
```

> **PTR collision note**: `vcf_ptr` and `esxi_ptr` records use only the last octet as the
> record name within each reverse zone. If two entries within the same map share the same
> last octet (e.g. `10.0.11.10` and `10.0.12.10` both in `vcf_components`), they will
> collide in the PTR zone. Ensure all IPs within each map have unique last octets.

### NSX Edge uplink IPs
IPs assigned to NSX Edge uplink interfaces during EVS bring-up. Must be within the NSX Uplink VLAN (default `10.0.16.x`). These are configured as Route Server BGP peer addresses.
```hcl
variable "nsx_edge_peer_ips" {
  default = {
    "edge-01" = "10.0.16.10"
    "edge-02" = "10.0.16.11"
  }
}
```

## On-Demand Capacity Reservation (Step 8)

`odcr.tf` contains a commented-out `aws_ec2_capacity_reservation` resource for `i4i.metal`. To enable it:

1. Verify your EC2 On-Demand Standard vCPU quota is >= 512 (`4 hosts × 128 vCPUs`). Check at **Service Quotas > Amazon EC2 > Running On-Demand Standard instances**. Request an increase if needed.
2. Uncomment the resource, variable, and output blocks in `odcr.tf`.
3. Run `terraform apply`.

The reservation uses `instance_match_criteria = "targeted"` — only your EVS deployment will consume it.

## Outputs

After `terraform apply`, `terraform output` prints:

| Output | Description |
|--------|-------------|
| `vpc_id` | EVS VPC ID |
| `service_access_subnet_id` | Service access subnet ID |
| `service_access_route_table_id` | Explicit route table ID (required for BGP propagation) |
| `resolver_primary_ip` | Primary DNS resolver IP (matches DHCP primary) |
| `resolver_secondary_ip` | Secondary DNS resolver IP (matches DHCP secondary) |
| `private_hosted_zone_id` | Route 53 private hosted zone ID |
| `dhcp_options_id` | DHCP options set ID |
| `route_server_id` | VPC Route Server ID |
| `route_server_endpoint_1_id` | Route Server endpoint 1 ID |
| `route_server_endpoint_2_id` | Route Server endpoint 2 ID |
| `evs_deploy_policy_arn` | ARN of `EVSDeploymentPolicy` |
| `evs_service_linked_role_arn` | ARN of `AWSServiceRoleForEVS` |

## Notes

- **`AmazonEVSEnvironmentPolicy`** is an AWS-managed IAM policy covering the minimum permissions for `CreateEnvironment`. The custom `EVSDeploymentPolicy` in `iam.tf` is equivalent and scoped to your account — use whichever fits your IAM model.
- **Transit Gateway is required** for on-premises connectivity. VPC peering, Direct Connect Private VIFs, and VGW-based Site-to-Site VPNs are not supported with Amazon EVS.
- **Security groups do not apply** to EVS VLAN subnet ENIs. NACLs are the only packet filtering mechanism for EVS traffic.
- **BFD is not supported for EVS.** BGP peers use `peer_liveness_detection = "bgp-keepalive"` — do not change this.
- **`persist_routes_duration = 2`**: Routes are held for 2 minutes after a BGP session drops. Valid range is 1–5 minutes. Increase this if you need more time for NSX to re-establish sessions after a restart.
- **Route propagation must target the explicit route table**, not the VPC main route table. The main route table silently drops BGP-propagated routes.
- **DHCP domain-name-servers must exactly match the resolver endpoint IPs** — resolver_ip_1 and resolver_ip_2 are used in both places intentionally.
- **IAM EC2 write actions** (`EC2ManageEVSResources`) are not tag-conditioned. EVS tags resources during creation — restricting by `AmazonEVSManaged` tag on write actions would deny EVS before it can apply the tag.
- The Terraform state contains no sensitive data. All secrets (VCF credentials) are managed by EVS during bring-up via Secrets Manager.

## Validate your environment

After deploying, use the companion validator to confirm all prerequisites are met end-to-end:

```bash
git clone https://github.com/gitvcloudone/EVS-PreREQ-Validate.git
cd EVS-PreREQ-Validate
pip install -r requirements.txt
python evs_validate.py --region us-east-1
```

See [EVS-PreREQ-Validate](https://github.com/gitvcloudone/EVS-PreREQ-Validate) for full documentation.

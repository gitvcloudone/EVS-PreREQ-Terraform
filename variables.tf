# ── General ──────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region where the EVS environment will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "az" {
  description = "Availability zone for all EVS resources. All resources must reside in the same AZ."
  type        = string
  default     = "us-east-1a"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the EVS VPC. Minimum /22. Cannot be changed after EVS deployment."
  type        = string
  default     = "10.0.0.0/16"
}

variable "service_access_cidr" {
  description = "CIDR for the Service Access Subnet (pre-created). Hosts Route Server endpoints and DNS Resolver ENIs."
  type        = string
  default     = "10.0.0.0/24"
}

# ── DNS ───────────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Private DNS domain for the EVS environment. Must match the Route 53 private hosted zone and DHCP options set."
  type        = string
  default     = "evs.vcloudone.local"
}

variable "resolver_ip_1" {
  description = "IP for Route 53 Resolver inbound endpoint #1 (primary DNS). Must be within service_access_cidr."
  type        = string
  default     = "10.0.0.10"
}

variable "resolver_ip_2" {
  description = "IP for Route 53 Resolver inbound endpoint #2 (secondary DNS). Must be within service_access_cidr."
  type        = string
  default     = "10.0.0.11"
}

# ── BGP / Route Server ────────────────────────────────────────────────────────

variable "route_server_asn" {
  description = "BGP ASN for the VPC Route Server. Must be a private ASN — 16-bit range (64512-65534) or 32-bit range (4200000000-4294967294). Must differ from nsx_peer_asn."
  type        = number
  default     = 65100
}

variable "nsx_peer_asn" {
  description = "BGP ASN configured on the NSX Tier-0 gateway. EVS auto-configures NSX to use this ASN. Default NSX value is 65000."
  type        = number
  default     = 65000
}

# ── VCF Component IP Map ──────────────────────────────────────────────────────
# IPs must be in the Management VM VLAN (default 10.0.11.0/24).
# These are used to create Route 53 A and PTR records before EVS bring-up.

variable "vcf_components" {
  description = "Map of VCF management appliance hostnames to IPs. Must be in the Management VM VLAN."
  type        = map(string)
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

# ── ESXi Host IP Map ──────────────────────────────────────────────────────────
# IPs must be in the Host Management VLAN (default 10.0.10.0/24).

variable "esxi_hosts" {
  description = "Map of ESXi hostname to IP. Must be in the Host Management VLAN."
  type        = map(string)
  default = {
    "esxi-01" = "10.0.10.21"
    "esxi-02" = "10.0.10.22"
    "esxi-03" = "10.0.10.23"
    "esxi-04" = "10.0.10.24"
  }
}

# ── Reverse DNS Zone Names ────────────────────────────────────────────────────
# These must match the /24 prefix of the IPs in esxi_hosts and vcf_components.
# If you change the host or management VM subnet, update these values too.
# Format: third-octet.second-octet.first-octet.in-addr.arpa
# Example: IPs in 10.0.10.0/24 → "10.0.10.in-addr.arpa"

variable "host_mgmt_reverse_zone" {
  description = "Reverse DNS zone for the ESXi Host Management VLAN. Must match the /24 of esxi_hosts IPs. Update if you change the host management subnet."
  type        = string
  default     = "10.0.10.in-addr.arpa"
}

variable "mgmt_vm_reverse_zone" {
  description = "Reverse DNS zone for the VCF Management VM VLAN. Must match the /24 of vcf_components IPs. Update if you change the management VM subnet."
  type        = string
  default     = "11.0.10.in-addr.arpa"
}

# ── NSX Edge BGP Peer IPs ─────────────────────────────────────────────────────
# These IPs are assigned to NSX Edge uplink interfaces during EVS bring-up.
# They must be within the NSX Uplink VLAN (default 10.0.16.0/24), not the
# Management VLAN. These are configured as Route Server peer addresses.

variable "nsx_edge_peer_ips" {
  description = "Map of NSX Edge node to its uplink IP in the NSX Uplink VLAN. Used as Route Server peer addresses."
  type        = map(string)
  default = {
    "edge-01" = "10.0.16.10"
    "edge-02" = "10.0.16.11"
  }
}


variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "service_access_cidr" {
  default = "10.0.1.0/24"
}

variable "az" {
  default = "us-east-1a"
}

variable "domain_name" {
  default = "evstest.com"
}

# VCF Component IP Map
variable "vcf_components" {
  type = map(string)
  default = {
    "sddc-manager" = "10.0.10.10"
    "vcenter"      = "10.0.10.11"
    "nsx-mgr-01"   = "10.0.10.12"
    "nsx-mgr-02"   = "10.0.10.13"
    "nsx-mgr-03"   = "10.0.10.14"
  }
}

# ESXi Host IP Map
variable "esxi_hosts" {
  type = map(string)
  default = {
    "esxi-01" = "10.0.11.21"
    "esxi-02" = "10.0.11.22"
    "esxi-03" = "10.0.11.23"
    "esxi-04" = "10.0.11.24"
  }
}

# NSX Edge Peering IPs
variable "nsx_edges" {
  type = map(string)
  default = {
    "edge-01" = "10.0.10.251"
    "edge-02" = "10.0.10.252"
  }
}

# ── Phase 9: On-Demand Capacity Reservation (ODCR) ───────────────────────────
# Uncomment to automate ODCR creation. Requires an EC2 vCPU quota of at least
# 512 for Running On-Demand Standard instances (4 × i4i.metal × 128 vCPUs).
# Check quota at: Service Quotas > Amazon EC2 >
#   Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances
#
# The reservation must be in the same AZ as the EVS environment (var.az).
# instance_match_criteria = "targeted" means only workloads that explicitly
# reference this reservation ID will consume it — other EC2 launches are
# unaffected.

# variable "odcr_instance_count" {
#   description = "Number of i4i.metal hosts to reserve. Minimum 4 for a standard EVS cluster."
#   type        = number
#   default     = 4
# }

# resource "aws_ec2_capacity_reservation" "evs_hosts" {
#   instance_type           = "i4i.metal"
#   instance_platform       = "Linux/UNIX"
#   availability_zone       = var.az
#   instance_count          = var.odcr_instance_count
#   instance_match_criteria = "targeted"
#   tags                    = { Name = "evs-odcr" }
# }

# output "odcr_id" {
#   description = "ID of the On-Demand Capacity Reservation for EVS i4i.metal hosts."
#   value       = aws_ec2_capacity_reservation.evs_hosts.id
# }

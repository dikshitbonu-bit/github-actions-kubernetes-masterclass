variable "name" {
  description = "VPC and cluster name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets (load balancers)"
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets (worker nodes)"
  type        = list(string)
}

variable "intra_subnets" {
  description = "CIDR blocks for intra subnets (control plane)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs (true saves cost in dev)"
  type        = bool
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

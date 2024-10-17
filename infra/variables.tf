#General variables
variable "region" {
  description = "The region in which the VPC will be created"
  type        = string
}

variable "team" {
  description = "The team name"
  type        = string
}
variable "component" {
  description = "The component name"
  type        = string
}
variable "environment" {
  description = "The environment name"
  type        = string
}
variable "enable_nat_gateway" {
  description = "A boolean flag to enable/disable NAT Gateways for the private subnets"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}
variable "vpc_name" { 
  description = "The name of the VPC"
  type        = string
}
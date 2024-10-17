locals {
  common_name = lower("${var.team}-${var.component}-${var.environment}")
  common_tags = {
    Project     = var.component
    Team        = var.team
    CostCenter  = var.team
    Environment = var.environment
    Provisioner = "terraform"
  }
  container_port = 80
}

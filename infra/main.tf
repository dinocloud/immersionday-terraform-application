################################################################################
# Data sources
################################################################################
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  tags = {
    Tier = "Public"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  tags = {
    Tier = "Private"
  }
}

data "aws_ecs_cluster" "ecs" {
  cluster_name = var.cluster_name
}
################################################################################
# Service
################################################################################

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.11.4"


  name        = "${local.common_name}-service"
  cluster_arn = data.aws_ecs_cluster.ecs.arn

  cpu    = 1024
  memory = 4096
  # Enables ECS Exec
  enable_execute_command = true

  # Container definition(s)
  container_definitions = {

    "${local.common_name}-frontend" = {
      cpu       = 512
      memory    = 1024
      essential = true
      image     = "${aws_ecr_repository.ecsrepository.repository_url}:latest"
      port_mappings = [
        {
          name          = "${local.common_name}-frontend"
          containerPort = local.container_port
          hostPort      = local.container_port
          protocol      = "tcp"
        }
      ]
      readonly_root_filesystem = false
      enable_cloudwatch_logging = true
      memory_reservation = 100
    }
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["ex_ecs"].arn
      container_name   = "${local.common_name}-frontend"
      container_port   = local.container_port
    }
  }

  subnet_ids = data.aws_subnets.private.ids

  security_group_rules = {
    alb_ingress_3000 = {
      type                     = "ingress"
      from_port                = local.container_port
      to_port                  = local.container_port
      protocol                 = "tcp"
      description              = "Service port"
      source_security_group_id = module.alb.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  service_tags = {
    "ServiceTag" = "Tag on service level"
  }

  tags = local.common_tags
}


################################################################################
# Supporting Resources
################################################################################

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name = "${local.common_name}-alb"

  load_balancer_type = "application"

  vpc_id  = data.aws_vpc.vpc.id
  subnets = data.aws_subnets.public.ids

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = data.aws_vpc.vpc.cidr_block
    }
  }

  listeners = {
    ex_http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "ex_ecs"
      }
    }
  }

  target_groups = {
    ex_ecs = {
      backend_protocol                  = "HTTP"
      backend_port                      = local.container_port
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      # There's nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }
  enable_deletion_protection = false
  tags                       = local.common_tags
}

resource "aws_ecr_repository" "ecsrepository" {
  name                 = local.common_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.40.0"
    }
  }
}
provider "aws" {
    region = "us-west-2"
    profile = "639035123345_PowerUserAccess"
}

terraform {
  backend "s3" {
    bucket = "eea-sre-challenge"
    key    = "terraform_state"
    region = "us-west-2"
    encrypt = true
    profile = "639035123345_PowerUserAccess"
    sts_region = "eu-west-1"
  }
}

module "payments_workers" {
    source     = "./workers"
    name       = "payments_workers"
    min_size   = 2
    desired_capacity = 2
    max_size   = 2
    instance_type = "t3.nano"
    cpuscale = 60.0
}

module "background_workers" {
    source     = "./workers"
    name       = "background_workers"
    min_size   = 2
    desired_capacity = 2
    max_size   = 2
    cpuscale = 60.0
}

module "messaging_background_workers" {
    source     = "./workers"
    name       = "messaging_background_workers"
    min_size   = 1
    max_size   = 4
}

resource "aws_autoscaling_schedule" "daily_messaging_scale_out" {
    scheduled_action_name  = "evening_payments_scale_out"
    min_size               = 1
    max_size               = 4
    desired_capacity       = -1
    recurrence             = "0 5 * * *"
    autoscaling_group_name = "${module.messaging_background_workers.scaling_group_id}"
}

resource "aws_autoscaling_schedule" "daily_messaging_scale_in" {
    scheduled_action_name  = "daily_messaging_scale_in"
    min_size               = 0
    max_size               = 4
    desired_capacity       = -1
    recurrence             = "0 22 * * *"
    autoscaling_group_name = "${module.messaging_background_workers.scaling_group_id}"
}

resource "aws_autoscaling_schedule" "evening_payments_scale_out" {
    scheduled_action_name  = "evening_payments_scale_out"
    min_size               = 4
    max_size               = 8
    desired_capacity       = -1
    recurrence             = "0 15 * * *"
    autoscaling_group_name = "${module.payments_workers.scaling_group_id}"
}

resource "aws_autoscaling_schedule" "evening_payments_scale_in" {
    scheduled_action_name  = "evening_payments_scale_in"
    min_size               = 2
    max_size               = 8
    desired_capacity       = -1
    recurrence             = "0 18 * * *"
    autoscaling_group_name = "${module.payments_workers.scaling_group_id}"
}

resource "aws_codedeploy_app" "sre-terraform-app" {
    name                  = "sre-terraform-app"
}

resource "aws_codedeploy_deployment_group" "workers-deployment_grp" {
    app_name              = "sre-terraform-app"
    deployment_group_name = "workers"
    service_role_arn      = "arn:aws:iam::639035123345:role/CodeDeploy-EC2-Role"
    deployment_config_name= "CodeDeployDefault.AllAtOnce"

    autoscaling_groups    = ["${module.background_workers.scaling_group_id}",
                             "${module.messaging_background_workers.scaling_group_id}",
                             "${module.payments_workers.scaling_group_id}"
                             ]
}

## Application servers

variable "elb_name" {
    type    = string
    default = "sre-application-alb"    
}

variable "vpc_id" {
    type    = string
    default = "vpc-0792372e93a253e53"    
}

variable "public_subnet_ids" {
    type = list(string)
    default = ["subnet-0c80a127103c7f99e", "subnet-08c1c9049e6629ec4"]
}

variable "sns_topic" {
    type    = string
    default = "arn:aws:sns:us-west-2:639035123345:Admins"
}

module "application" {
    source     = "./application"
    alb_security_group_id = aws_security_group.alb_security_group.id
    target_group_arn = aws_lb_target_group.application.arn

    min_size   = 2
    max_size   = 4
}

resource "aws_security_group" "alb_security_group" {
  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"

  vpc_id = var.vpc_id

  // Inbound rules: Allow HTTP and HTTPS traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Outbound rule: Allow all traffic to go out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

resource "aws_lb" "application" {
    name               = "sre-application-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb_security_group.id]
    subnets            = var.public_subnet_ids

    tags = {
        Name = "sre-application-alb"
    }
}

resource "aws_lb_target_group" "application" {
    name        = "sre-application-tg"
    port        = 80
    protocol    = "HTTP"
    vpc_id      = "${var.vpc_id}"
    target_type = "instance"

    health_check {
        path                = "/"
        interval            = 30
        timeout             = 10
        healthy_threshold   = 3
        unhealthy_threshold = 3
    }

    tags = {
        Name = "sre-application-tg"
    }
}

resource "aws_lb_listener" "application" {
    load_balancer_arn = "${aws_lb.application.arn}"
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = "${aws_lb_target_group.application.arn}"
    }
}

resource "aws_lb_listener_rule" "application" {
    listener_arn = "${aws_lb_listener.application.arn}"
    priority     = 100

    action {
        type             = "forward"
        target_group_arn = "${aws_lb_target_group.application.arn}"
    }

    condition {
        path_pattern {
            values = ["/"]
        }
    }
}

resource "aws_codedeploy_deployment_group" "application-deployment-grp" {
    app_name              = "sre-terraform-app"
    deployment_group_name = "application"
    service_role_arn      = "arn:aws:iam::639035123345:role/CodeDeploy-EC2-Role"

    deployment_style {
        deployment_option = "WITH_TRAFFIC_CONTROL"
        deployment_type = "IN_PLACE"
    }

    load_balancer_info {
       
        target_group_info {
            name = aws_lb_target_group.application.name
        }
    }

    trigger_configuration {
        trigger_events    = ["DeploymentFailure"]
        trigger_name      = "On Failed Deployment"
        trigger_target_arn= "${var.sns_topic}"
    }

    auto_rollback_configuration {
        enabled = false
        events = ["DEPLOYMENT_FAILURE"]
    }

    autoscaling_groups    = ["${module.application.scaling_group_id}",
                            ]
}

output "alb_security_group_id" {
  value = aws_security_group.alb_security_group.id
}

output "target_group_arn" {
  value = aws_lb_target_group.application.arn
}

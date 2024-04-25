variable "application_ami" {
    type    = string
    default = "ami-0cd59ecaf368e5ccf"
}

variable "security_groups" {
    type = list(string)
    default = ["sg-027c1c5aeadbd88b9"]
}

variable "alb_security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "min_size" {
    type = number
    default = 1
}

variable "desired_capacity" {
  type = number
  default = 2
}

variable "instance_type" {
    type = string
    default = "t3.micro"
}

variable "max_size" {
    type = number
    default = 4
}

variable "cpuscale" {
    type = number
    default = 60.0
}

variable "cpu_credits" {
    type = string
    default = "unlimited"
}

variable "extra_tags" {
  type = map(string)
  default = {
    Type        = "worker"
    Environment = "production"
    Owner       = "software"
  }
}

resource "aws_launch_template" "application" {
    name                   = "sre_application"
    image_id               = "${var.application_ami}"
    key_name               = "Keys"
    instance_type          = "${var.instance_type}"
    vpc_security_group_ids = concat(var.security_groups, [var.alb_security_group_id])
    tag_specifications {
        resource_type = "instance"

        tags = merge(            
            {
                Name = "sre_application"
            },
            var.extra_tags,
            )
    }
  
    user_data              = base64encode(templatefile("${path.module}/userdata.tmpl", {}))

    iam_instance_profile {
        name = "CodeDeploy-EC2-Instance-Profile"
    }

    lifecycle {
        create_before_destroy = true
    }

    credit_specification {
        cpu_credits = "${var.cpu_credits}"
    }
    block_device_mappings {
      device_name = "/dev/sda1"

    ebs {
      volume_size = 100
      volume_type = "gp3"
    }
  }
}

resource "aws_autoscaling_group" "application" {
    name = "application"
    min_size = "${var.min_size}"
    desired_capacity = "${var.desired_capacity}"
    max_size = "${var.max_size}"
    vpc_zone_identifier = ["subnet-0be246c92f4a60ad5", "subnet-00d971a4cb1677c15"]

    launch_template {
      id        = "${aws_launch_template.application.id}"
      version   = "$Latest"
    }
    
    target_group_arns = [var.target_group_arn]
}

resource "aws_autoscaling_policy" "application_cpu" {
    name                   = "cpu-autoscaling"
    adjustment_type        = "ChangeInCapacity"
    policy_type            = "TargetTrackingScaling"
    autoscaling_group_name = "${aws_autoscaling_group.application.name}"
    target_tracking_configuration {
        predefined_metric_specification {
            predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = "${var.cpuscale}"
    }
    depends_on = [aws_autoscaling_group.application]
}

output "scaling_group_id" {
    value = "${aws_autoscaling_group.application.id}"
}

variable "workers_ami" {
    type    = string
    default = "ami-0cd59ecaf368e5ccf"  #not present 
}

variable "security_groups" {
    type = list(string)
    default = ["sg-027c1c5aeadbd88b9"] #not present create this security group
}

variable "name" {
    type = string
}

variable "min_size" {
    type = number
    default = 1
}

variable "max_size" {
    type = number
    default = 1
}

variable "desired_capacity" {
  type = number
  default = 1
}

variable "instance_type" {
    type = string
    default = "t3.nano"
}

variable "cpuscale" {
    type = number
    default = 40.0
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


resource "aws_launch_template" "workers" {
    name                   = "workers_${var.name}"
    image_id               = "${var.workers_ami}"
    key_name               = "Keys"
    instance_type          = "${var.instance_type}"
    vpc_security_group_ids = "${var.security_groups}"  #correct this 
    tag_specifications {
        resource_type = "instance"

        tags = merge(            
            {
                Name = "workers_${var.name}"
            },
            var.extra_tags,
            )
    }    

    iam_instance_profile {
        name = "CodeDeploy-EC2-Instance-Profile"  # this not present 
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
        volume_size = 20
        volume_type = "gp3"
      }
  }
    
}

resource "aws_autoscaling_group" "workers" {
    name = "workers_${var.name}"
    min_size = "${var.min_size}"
    desired_capacity = "${var.desired_capacity}"
    max_size = "${var.max_size}"
    vpc_zone_identifier = ["subnet-0be246c92f4a60ad5", "subnet-00d971a4cb1677c15"]  # This hard coded not picked dynamically
 
    launch_template {
      id        = "${aws_launch_template.workers.id}"
      version   = "$Latest"
    }
}

resource "aws_autoscaling_policy" "workers_cpu" {
    name                   = "cpu-autoscaling"
    adjustment_type        = "ChangeInCapacity"
    policy_type            = "TargetTrackingScaling"
    autoscaling_group_name = "${aws_autoscaling_group.workers.name}"
    target_tracking_configuration {
        predefined_metric_specification {
            predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = "${var.cpuscale}"
    }
    depends_on = [aws_autoscaling_group.workers]
}

output "scaling_group_id" {
    value = "${aws_autoscaling_group.workers.id}"
}

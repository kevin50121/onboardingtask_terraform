#Two kinds of way to build services by terraform , 
#resource: Building a whole new service
#data: Building a new service based on exisiting resources 
#using resource in this case.

#Create a new cluster for OnboardingTask_Terraform ,name as OnboardingTask_Terraform
resource "aws_ecs_cluster" "terraform_cluster" {
  name = "onboardingtask-terraform"
}

#Define provider and region
provider "aws" {
  region = "ap-southeast-1"
}

#Create ecs instance for OnboardingTask_Terraform (Launch an Instance and use ecsInstanceRole & user-data.txt)
data "aws_ami" "ecs-optimized" {
  most_recent = true

  filter {
    name   = "image-id"
    values = ["ami-04e47a1e7ce1d448a"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["591542846629"] 
}
  resource "aws_instance" "terraform_instance" {
    ami           = "ami-04e47a1e7ce1d448a"
    instance_type = "t2.micro"
    subnet_id     = "subnet-fdd98abb"
    vpc_security_group_ids = ["sg-bc40ddd9"]
    iam_instance_profile = "ecsInstanceRole"
    key_name = "kevin_test"
    user_data = <<EOF
#!/bin/bash
# Create user-data.txt 
# User-data.txt :
echo ECS_CLUSTER=onboardingtask-terraform >> /etc/ecs/ecs.config
      EOF
    tags = {
      Name = "onboardingtask_terraform"
    }
  }
#Create target group for OnboardingTask_Terraform
 resource "aws_lb_target_group" "terraform_targetgroup" {
   name     = "onboardingtask-terraform-tg"
   port     = "80"
   protocol = "HTTP"
   vpc_id   = "vpc-0f62be6a"
  #  health_check {    
  #       healthy_threshold   = 3    
  #       unhealthy_threshold = 3
  #       timeout             = 10    
  #       interval            = 15       
  #       port                = "80"  
  # }
  depends_on = ["aws_lb.terraform_lb"]
 }

# Create a new load balancer for OnboardingTask_Terraform 
  resource "aws_lb" "terraform_lb" {
  name               = "terraform-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.security_group_id}"]
  subnets            = ["${var.subnet_id_1a}","${var.subnet_id_1c}"]

  enable_deletion_protection = true
  
  depends_on = ["aws_instance.terraform_instance"]
  tags = {
    Name = "onboardingtask_terraform"
  }
}
#Set listener for alb
resource "aws_lb_listener" "terraform_lb_listener" {
  load_balancer_arn = "${aws_lb.terraform_lb.arn}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.terraform_targetgroup.arn}"
  }
}

#Use exisiting task-def kevin_onboardingtasks_flask as the taskdef

 resource "aws_ecs_task_definition" "terraform_task_definition" {
   family = "kevin_onboardingtasks_flask"
  container_definitions = <<DEFINITION
 [
   {
     "cpu": 128,
     "essential": true,
     "image": "990090895087.dkr.ecr.ap-southeast-1.amazonaws.com/kevintest_11:${var.version}",
     "memory": 128,
     "portMappings": [
                 {
                     "containerPort": 5000, 
                     "hostPort": 0, 
                     "protocol": "tcp"
                 }
             ], 
     "name": "terraform_flask"
   }
 ]
 DEFINITION
 }

 data "aws_ecs_task_definition" "terraform_task_definition" {
   task_definition = "${aws_ecs_task_definition.terraform_task_definition.family}"
 }

#Create Service for ECS-clusters 
 resource "aws_ecs_service" "terraform_ecs_service" {
   name            = "OnboardingTask_Terraform"
   cluster         = "${aws_ecs_cluster.terraform_cluster.arn}"
   task_definition = "${aws_ecs_task_definition.terraform_task_definition.family}:${max("${aws_ecs_task_definition.terraform_task_definition.revision}", "${data.aws_ecs_task_definition.terraform_task_definition.revision}")}"
   load_balancer {
     target_group_arn = "${aws_lb_target_group.terraform_targetgroup.arn}"
     container_name   = "terraform_flask"
     container_port   =  "5000"
   }
   desired_count = 1
   deployment_maximum_percent         = 100
   deployment_minimum_healthy_percent = 0
   depends_on = ["aws_lb_target_group.terraform_targetgroup"]
 }
 
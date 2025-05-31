# Creating Bastion Host Security group 
resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-bastion_sg"
  description = "Allow SSH"
  vpc_id      = var.vpc

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-bastion_sg"
  }
}

# Data source to get the latest RedHat AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # RedHat's owner ID
  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Create Launch Template
resource "aws_launch_template" "lnch_tmpl" {
  name_prefix   = "${var.name}-bastion-tmpl"
  image_id      = data.aws_ami.redhat.id
  instance_type = "t2.medium"
  key_name      = var.keypair
    user_data = base64encode(templatefile("./module/bastion/userdata.sh", {
    privatekey = var.privatekey
  }))
  network_interfaces {
    security_groups             = [aws_security_group.bastion_sg.id]
    associate_public_ip_address = true
  }
}

# Create ASG for Bastion Host
resource "aws_autoscaling_group" "bastion-asg" {
  name                      = "${var.name}-bastion-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true
  launch_template {
    id      = aws_launch_template.lnch_tmpl.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.subnets

  tag {
    key                 = "Name"
    value               = "${var.name}-bastion-asg"
    propagate_at_launch = true
  }
}

# Creat ASG policy for Bastion Host
resource "aws_autoscaling_policy" "bastion-asg-policy" {
  name                   = "${var.name}-bastion-asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.bastion-asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

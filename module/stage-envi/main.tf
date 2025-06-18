# Stage Security Group
resource "aws_security_group" "stage_sg" {
  name        = "${var.name}-stage-sg"
  description = "Stage security group"
  vpc_id      = var.vpc_id

  ingress {
    description              = "SSH access from Bastion"
    from_port                = 22
    to_port                  = 22
    protocol                 = "tcp"
    source_security_group_id = var.bastion_sg
  }

  ingress {
    description              = "SSH access from Ansible"
    from_port                = 22
    to_port                  = 22
    protocol                 = "tcp"
    source_security_group_id = var.ansible
  }

  ingress {
    description = "HTTP access from ALB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-stage-sg"
  }
}

data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"]
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

# Launch Template
resource "aws_launch_template" "stage_lnch_tmpl" {
  image_id      = data.aws_ami.redhat.id
  name_prefix   = "${var.name}-stage-web-tmpl"
  instance_type = "t2.medium"
  key-name      = var.key_name

  user_data = base64encode(templatefile("./module/stage-envi/docker-script.sh", {
    nexus_ip   = var.nexus_ip,
    nr_key     = var.nr_key,
    nr_acct_id = var.nr_acct_id
  }))

  network_interfaces {
    security_groups = [aws_security_group.stage_sg.id]
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "stage_autoscaling_grp" {
  name                      = "${var.name}-stage-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.stage_lnch_tmpl.id
    version = "$Latest"
  }

  vpc_zone_identifier = [var.pri_subnet1, var.pri_subnet2]
  target_group_arns   = [aws_lb_target_group.stage_target_group.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-stage-asg"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy
resource "aws_autoscaling_policy" "stage_asg_policy" {
  name                   = "asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.stage_autoscaling_grp.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Stage ALB
resource "aws_lb" "stage_lb" {
  name               = "${var.name}-stage-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.stage_elb_sg.id]
  subnets            = [var.pub_subnet1, var.pub_subnet2]

  tags = {
    Name = "${var.name}-stage-LB"
  }
}

# ELB Security Group
resource "aws_security_group" "stage_elb_sg" {
  name        = "${var.name}-stage-elb-sg"
  description = "Stage ELB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-stage-elb-sg"
  }
}

# Target Group
resource "aws_lb_target_group" "stage_target_group" {
  name        = "${var.name}-stage-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc-id
  target_type = "instance"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
    path                = "/"
  }

  tags = {
    Name = "${var.name}-stage-tg"
  }
}

# HTTP Listener
resource "aws_lb_listener" "stage_lb_listener_http" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_target_group.arn
  }
}

# HTTPS Listener
resource "aws_lb_listener" "stage_lb_listener_https" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_target_group.arn
  }
}

# Route 53 Zone
data "aws_route53_zone" "auto_discovery_zone" {
  name         = var.domain
  private_zone = false
}

# Route 53 Record
resource "aws_route53_record" "stage_record" {
  zone_id = data.aws_route53_zone.auto_discovery_zone.zone_id
  name    = "stage.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.stage_lb.dns_name
    zone_id                = aws_lb.stage_lb.zone_id
    evaluate_target_health = true
  }
}

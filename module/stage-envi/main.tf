#stage security group
resource "aws_security_group" "stage-sg" {
  name        = "${var.name}-stage-sg"
  description = "stage Security group"
  vpc_id      = var.vpc-id
  ingress {
    description     = "SSH access from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg, var.ansible]
  }

  ingress {
    description = "HTTP access from ALB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.stage-elb-sg.id]
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
resource "aws_launch_template" "stage_lnch_tmpl" {
  image_id      = data.aws_ami.redhat.id
  name_prefix   = "${var.name}-stage-web-tmpl"
  instance_type = "t2.medium"
  key_name      = var.key-name
  user_data = base64encode(templatefile("./module/stage-env/docker-script.sh", {
    nexus-ip   = var.nexus-ip,
    nr-key     = var.nr-key,
    nr-acct-id = var.nr-acct-id
  }))

  network_interfaces {
    security_groups = [aws_security_group.stage-sg.id]
  }
  metadata_options {
    http_tokens = "required"
  }
}

# Create Auto Scaling Group
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
  vpc_zone_identifier = [var.pri-subnet1, var.pri-subnet2]
  target_group_arns   = [aws_lb_target_group.stage-target-group.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-stage-asg"
    propagate_at_launch = true
  }
}
# Created autoscaling group policy
resource "aws_autoscaling_policy" "stage-asg-policy" {
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

# Create Application Load Balancer for stage
resource "aws_lb" "stage_LB" {
  name               = "${var.name}-stage-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.stage-elb-sg.id]
  subnets            = [var.pub-subnet1, var.pub-subnet2]
  tags = {
    Name = "${var.name}-stage-LB"
  }
}
#stage-elb security group
resource "aws_security_group" "stage-elb-sg" {
  name        = "${var.name}-stage-elb-sg"
  description = "stage-elb Security group"
  vpc_id      = var.vpc-id
  ingress {
    description = "HTTP access from ALB"
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

#Create Target group for load Balancer
resource "aws_lb_target_group" "stage-target-group" {
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

# Create load balance listener for http
resource "aws_lb_listener" "stage_load_balancer_listener_http" {
  load_balancer_arn = aws_lb.stage_LB.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage-target-group.arn
  }
}
# Create load balance listener for https
resource "aws_lb_listener" "stage_load_balancer_listener_https" {
  load_balancer_arn = aws_lb.stage_LB.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm-cert-arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage-target-group.arn
  }
}
# Create Route 53 record for stage server
data "aws_route53_zone" "auto-discovery-zone" {
  name         = var.domain
  private_zone = false
}

# Create Route 53 record for stage server
resource "aws_route53_record" "stage-record" {
  zone_id = data.aws_route53_zone.auto-discovery-zone.zone_id
  name    = "stage.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_lb.stage_LB.dns_name
    zone_id                = aws_lb.stage_LB.zone_id
    evaluate_target_health = true
  }
}

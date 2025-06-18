#prod security group
resource "aws_security_group" "prod-sg" {
  name        = "${var.name}-prod-sg"
  description = "prod Security group"
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
    security_groups = [aws_security_group.prod-elb-sg.id]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-prod-sg"
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
resource "aws_launch_template" "prod_lnch_tmpl" {
  image_id      = data.aws_ami.redhat.id
  name_prefix   = "${var.name}-prod-web-tmpl"
  instance_type = "t2.medium"
  key_name      = var.key-name
 uuser_data = base64encode(templatefile("${path.module}/docker-script.sh", {
  nexus_ip   = var.nexus_ip
  nr_key     = var.nr_key
  nr_acct_id = var.nr_acct_id
}))


  network_interfaces {
    security_groups = [aws_security_group.prod-sg.id]
  }
  metadata_options {
    http_tokens = "required"
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "prod_autoscaling_grp" {
  name                      = "${var.name}-prod-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true
  launch_template {
    id      = aws_launch_template.prod_lnch_tmpl.id
    version = "$Latest"
  }
  vpc_zone_identifier = [var.pri_subnet1, var.pri_subnet2]
  target_group_arns   = [aws_lb_target_group.prod-target-group.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-prod-asg"
    propagate_at_launch = true
  }
}
# Created autoscaling group policy
resource "aws_autoscaling_policy" "prod-asg-policy" {
  name                   = "asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.prod_autoscaling_grp.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Create Application Load Balancer for prod
resource "aws_lb" "prod_LB" {
  name               = "${var.name}-prod-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod-elb-sg.id]
  subnets            = [var.pub_subnet1, var.pub_subnet2]
  tags = {
    Name = "${var.name}-prod-LB"
  }
}
#prod-elb security group
resource "aws_security_group" "prod-elb-sg" {
  name        = "${var.name}-prod-elb-sg"
  description = "prod-elb Security group"
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
    Name = "${var.name}-prod-elb-sg"
  }
}

#Create Target group for load Balancer
resource "aws_lb_target_group" "prod-target-group" {
  name        = "${var.name}-prod-tg"
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
    Name = "${var.name}-prod-tg"
  }
}

# Create load balance listener for http
resource "aws_lb_listener" "prod_load_balancer_listener_http" {
  load_balancer_arn = aws_lb.prod_LB.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod-target-group.arn
  }
}
# Create load balance listener for https
resource "aws_lb_listener" "prod_load_balancer_listener_https" {
  load_balancer_arn = aws_lb.prod_LB.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm-cert-arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod-target-group.arn
  }
}
# Create Route 53 record for prod server
data "aws_route53_zone" "auto-discovery-zone" {
  name         = var.domain
  private_zone = false
}

# Create Route 53 record for prod server
resource "aws_route53_record" "prod-record" {
  zone_id = data.aws_route53_zone.auto-discovery-zone.zone_id
  name    = "prod.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_lb.prod_LB.dns_name
    zone_id                = aws_lb.prod_LB.zone_id
    evaluate_target_health = true
  }
}

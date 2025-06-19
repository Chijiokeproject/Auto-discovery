# Security group for SonarQube server
resource "aws_security_group" "sonarqube_sg" {
  name        = "${var.name}-sonarqube-sg"
  description = "Allow SSH and SonarQube UI"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
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
    Name = "${var.name}-sonarqube-sg"
  }
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# Create Sonarqube Server
resource "aws_instance" "sonarqube_server" {
  ami                         = data.aws_ami.ubuntu.id # Use the latest Ubuntu AMI
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.sonarqube_sg.id]
  key_name                    = var.keypair
  subnet_id                   = var.subnet_id
  user_data                   = file("${path.module}/sonar_userdata.sh")
  associate_public_ip_address = true
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.name}-sonarqube-server"
  }
}

# ELB Security Group
resource "aws_security_group" "elb_sonar_sg" {
  name        = "${var.name}-elb-sonar-sg"
  description = "Allow HTTPS to SonarQube via ELB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ✅ Allow from anywhere — or restrict as needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-elb-sonar-sg"
  }
}


# Elastic Load Balancer
resource "aws_elb" "elb_sonar" {
  name            = "${var.name}-elb-sonar"
  subnets         = var.public_subnets
  security_groups = [aws_security_group.elb_sonar_sg.id]

  listener {
    instance_port      = 9000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = var.acm_certificate_arn
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:9000"
    interval            = 30
  }

  instances                   = [aws_instance.sonarqube_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${var.name}-elb-sonar"
  }
}

# ACM Certificate
resource "aws_acm_certificate" "auto_acm_cert" {
  domain_name       = "chijiokedevops.space"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 Record
resource "aws_route53_record" "sonarqube_record" {
  zone_id = var.route53_zone_id
  name    = "sonar.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_elb.elb_sonar.dns_name
    zone_id                = aws_elb.elb_sonar.zone_id
    evaluate_target_health = true
  }
}






# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for SonarQube EC2 instance
resource "aws_security_group" "sonarqube_sg" {
  name        = "${var.name}sonarqube-sg"
  description = "Allow SSH and SonarQube UI"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube UI"
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
}

# Launch SonarQube EC2 instance
resource "aws_instance" "sonarqube_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sonarqube_sg.id]
  associate_public_ip_address = true
  key_name                    = var.keypair

  user_data = file("${path.module}/sonar_userdata.sh") # make sure this file exists

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "SonarQube-Server"
  }
}

# Security Group for ELB
resource "aws_security_group" "elb_sonarqube_sg" {
  name        = "${var.name}elb-sonarqube-sg"
  description = "Allow HTTPS to SonarQube ELB"
  vpc_id      = var.vpc

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "elb-sonarqube-sg"
  }
}

# Create Classic Load Balancer
resource "aws_elb" "sonarqube_elb" {
  name            = "${var.name}-sonarqube-elb"
  subnets         = [var.subnet1_id, var.subnet2_id]
  security_groups = [aws_security_group.elb_sonarqube_sg.id]

  listener {
    instance_port      = 9000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = var.acm_certificate_arn

  }
  health_check {
    target              = "TCP:9000"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances = [aws_instance.sonarqube_server.id]
    cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "sonarqube-elb"
  }
}

# Create Route 53 record for sonarqube host
data "aws_route53_zone" "auto-discovery-zone" {
  name         = var.domain
  private_zone = false
}
# ACM Certificate
#resource "aws_acm_certificate" "sonarqube_cert" {
 # domain_name       = "sonar.${var.domain}"
  #validation_method = "DNS"

  #lifecycle {
   # create_before_destroy = true
  #}
#}

# Route53 Record
resource "aws_route53_record" "sonarqube_dns" {
zone_id = data.aws_route53_zone.auto-discovery-zone.zone_idd
name    = "sonar.${var.domain}"
type    = "A"

  alias {
    name                   = aws_elb.sonarqube.dns_name
    zone_id                = aws_elb.sonarqube.zone_id
    evaluate_target_health = true
  }
}



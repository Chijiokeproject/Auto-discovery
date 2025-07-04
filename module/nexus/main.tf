# Creating Nexus Security group 
resource "aws_security_group" "nexus-sg" {
  name        = "${var.name}-nexus-sg"
  description = "Allow SSH, HTTP, HTTPS, nexus and docker "
  vpc_id      = var.vpc

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg]
  }
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8085
    to_port     = 8085
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
    Name = "${var.name}-nexus-sg"
  }
}

# Data source to get the latest RedHat AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # RedHat's owner ID
  filter {
    name   = "name"
    values = ["RHEL-9.4.0_HVM-20240605-x86_64-82-Hourly2-GP3"]
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

resource "aws_instance" "nexus" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t2.medium"
  subnet_id                   = var.subnet
  vpc_security_group_ids      = [aws_security_group.nexus-sg.id]
  key_name                    = var.keypair
  associate_public_ip_address = true
  user_data = local.userdata
  root_block_device {
    volume_size = 30    # Size in GB
    volume_type = "gp3" # General Purpose SSD (recommended)
    encrypted   = true  # Enable encryption (best practice)
  }

  tags = {
    Name = "${var.name}-nexus-server"
  }
}
# Create Security group for the nexus elb
resource "aws_security_group" "nexus-elb-sg" {
  name        = "${var.name}-nexus-elb-sg"
  description = "Allow HTTPS"
  vpc_id      = var.vpc

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-nexus-elb-sg"
  }
}
# Create elastic Load Balancer for nexus
resource "aws_elb" "elb_nexus" {
  name            = "${var.name}-nexus-elb"
  subnets         = [var.subnet1_id, var.subnet2_id]
  security_groups = [aws_security_group.nexus-elb-sg.id]

  listener {
    instance_port      = 8081
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = var.acm_certificate_arn
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
    target              = "TCP:8081"
  }
  instances                   = [aws_instance.nexus.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${var.name}-nexus-elb"
  }
}

# Create Route 53 record for nexus host
data "aws_route53_zone" "auto-discovery-zone" {
  name         = var.domain
  private_zone = false
}

# Create Route 53 record for nexus server
resource "aws_route53_record" "nexus-record" {
  zone_id = data.aws_route53_zone.auto-discovery-zone.zone_id
  name    = "nexus.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_nexus.dns_name
    zone_id                = aws_elb.elb_nexus.zone_id
    evaluate_target_health = true
  }
}

resource "null_resource" "update_jenkins" {
  depends_on = [aws_instance.nexus]

  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": ["${aws_instance.nexus.public_ip}:8085"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
EOT
  }
}




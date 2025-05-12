locals {
  name = "auto-discovery"
}
#Creating kms key
resource "aws_kms_key" "auto-kms-key" {
  description             = "${local.name}-vault-kms-key" // the kms key 
  deletion_window_in_days = 10                            // 10 days
  enable_key_rotation     = true                          // true
}
# alias of the kms key
resource "aws_kms_alias" "auto-kms-key" {
  name          = "alias/${local.name}-kms-key"
  target_key_id = aws_kms_key.auto-kms-key.key_id
}

resource "aws_iam_role" "vault_role" {
  name = "${local.name}-vault-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Create IAM Policy for Vault to access KMS
resource "aws_iam_role_policy" "vault_kms_access" {
  name = "${local.name}-vault_kms-access"
  role = aws_iam_role.vault_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "${aws_kms_key.auto-kms-key.arn}"
      }
    ]
  })
}
resource "aws_iam_instance_profile" "vault-profile" {
  name = "${local.name}-vault-profile"
  role = aws_iam_role.vault_role.name
}

# Create Vault Security Group
resource "aws_security_group" "vault_sg" {
  name        = "vault-sg"
  description = "Allow SSH, HTTP, HTTPS, and Vault UI/API"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}
# Ubuntu AMI lookup
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# Create Vault Server Instance
resource "aws_instance" "vault_server" {
  ami                  = data.aws_ami.ubuntu.id # Ubuntu in eu-west-2
  instance_type        = "t2.medium"
  key_name             = aws_key_pair.public_key.key_name
  security_groups      = [aws_security_group.vault_sg.name]
  iam_instance_profile = aws_iam_instance_profile.vault-profile.id
  user_data = templatefile("./vault_userdata.sh", {
    var1 = "eu-west-2",
    var2 = aws_kms_key.auto-kms-key.id
  })

  tags = {
    Name = "${local.name}-VaultServer"
  }
}

# Create keypair resource
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "private_key" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "${local.name}-key.pem"
  file_permission = "400"
}
resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.keypair.public_key_openssh
}

#create a time sleep resource that allow terraform to wait till vault server is ready
resource "time_sleep" "wait_3_min" {
  depends_on      = [aws_instance.vault_server]
  create_duration = "180s"
}

#create null resource to fetch vault token
resource "null_resource" "fetch_token" {
  depends_on = [time_sleep.wait_3_min]
  # create terraform provisioner to help fetch token file from the vault server
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ./${local.name}-key.pem ubuntu@${aws_instance.vault_server.public_ip}:/home/ubuntu/token.txt ."
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ./token.txt"
  }
}

# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "auto-acm-cert" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}auto-acm-cert"
  }
}
# Fetch Route 53 Zone for DNS Validation
data "aws_route53_zone" "auto-discovery-zone" {
  name         = "chijiokedevops.space"
  private_zone = false
}

# Fetch DNS Validation Records for ACM Certificate
resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.auto-acm-cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  # Create DNS Validation Record for ACM Certificate
  zone_id         = data.aws_route53_zone.auto-discovery-zone.zone_id
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  depends_on      = [aws_acm_certificate.auto-acm-cert]
}

# Validate the ACM Certificate after DNS Record Creation
resource "aws_acm_certificate_validation" "auto_cert_validation" {
  certificate_arn         = aws_acm_certificate.auto-acm-cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
  depends_on              = [aws_acm_certificate.auto-acm-cert]
}

#Create Security Group for Vault Elastic Load Balancer
resource "aws_security_group" "elb-vault-sg" {
  name        = "elb-vault-sg"
  description = "Allow HTTPS"

  ingress {
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
}

# Create load balancer for Vault Server
resource "aws_elb" "elb-vault" {
  name               = "vault-elb"
  availability_zones = ["eu-west-2a", "eu-west-2b"]

  listener {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.auto-acm-cert.arn
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8200"
    interval            = 30
  }

  instances                   = [aws_instance.vault_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${local.name}-elb-vault"
  }
}

# Create Route 53 Hosted Zone
data "aws_route53_zone" "vault-zone" {
  name         = var.domain
  private_zone = false
}

# Create Route 53 A Record for Vault Server
resource "aws_route53_record" "vault-record" {
  zone_id = data.aws_route53_zone.vault-zone.zone_id
  name    = "vault.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb-vault.dns_name
    zone_id                = aws_elb.elb-vault.zone_id
    evaluate_target_health = true
  }
}


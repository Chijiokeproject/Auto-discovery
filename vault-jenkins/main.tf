locals {
  name = "auto-discovery"
}

# Create keypair resource
resource "tls_private_key" "vault_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "private_key" {
  content         = tls_private_key.vault_key.private_key_pem
  filename        = "${local.name}-key.pem"
  file_permission = "400"
}

resource "aws_key_pair" "vault_key" {
  key_name   = "${local.name}vault-key"
  public_key = tls_private_key.vault_key.public_key_openssh
}

#Creating kms key
resource "aws_kms_key" "vault_key" {
  description             = "Vault encryption key"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}
# alias of the kms key
resource "aws_kms_alias" "vault_alias" {
  name          = "alias/${local.name}-kms-key"
  target_key_id = aws_kms_key.vault_key.id
  lifecycle {
    create_before_destroy = true
  }
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
resource "aws_iam_role_policy" "vault_kms_policy" {
  name = "${local.name}-vault-kms-policy"
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
        Resource = "${aws_kms_key.vault_key.arn}"
      }
    ]
  })
}
resource "aws_iam_instance_profile" "profile_vault" {
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
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t2.medium"
  key_name             = aws_key_pair.vault_key.key_name
  security_groups      = [aws_security_group.vault_sg.name]
  iam_instance_profile = aws_iam_instance_profile.profile_vault.id

  user_data = templatefile("./vault_userdata.sh", {
    var1 = "eu-west-3",
    var2 = aws_kms_key.vault_key.id
  })

  tags = {
    Name = "${local.name}-VaultServer"
  }
}



#create a time sleep resource that allow terraform to wait till vault server is ready
resource "time_sleep" "wait_3_min" {
  depends_on      = [aws_instance.vault_server]
  create_duration = "300s"
}

#create null resource to fetch vault token
#resource "null_resource" "fetch_token" {
# depends_on = [time_sleep.wait_3_min]
# create terraform provisioner to help fetch token file from the vault server
resource "null_resource" "fetch_token" {
  depends_on = [aws_instance.vault_server, time_sleep.wait_3_min]

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i auto-discovery-key.pem ubuntu@${aws_instance.vault_server.public_ip}:/home/ubuntu/token.txt ."
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ./token.txt"
  }
}

# Fetch Route 53 Zone for DNS Validation
data "aws_route53_zone" "auto-discovery-zone" {
  name         = "chijiokedevops.space"
  private_zone = false
}

# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "auto_acm_cert" {
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

# Fetch DNS Validation Records for ACM Certificate
resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.auto_acm_cert.domain_validation_options : dvo.domain_name => {
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
  depends_on      = [aws_acm_certificate.auto_acm_cert]
}

# Validate the ACM Certificate after DNS Record Creation
resource "aws_acm_certificate_validation" "auto_cert_validation" {
  certificate_arn         = aws_acm_certificate.auto_acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
  depends_on              = [aws_acm_certificate.auto_acm_cert]
}

#Create Security Group for Vault Elastic Load Balancer
resource "aws_security_group" "elb_vault_sg" {
  name        = "elb-vault-sg"
  description = "Allow HTTPS"

  ingress {
    from_port   = 22
    to_port     = 22
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

# Create load balancer for Vault Server
resource "aws_elb" "elb_vault" {
  name               = "vault-elb"
  availability_zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  security_groups    = [aws_security_group.elb_vault_sg.id]

  listener {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.auto_acm_cert.arn
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
# Create Route 53 A Record for Vault Server
resource "aws_route53_record" "vault_record" {
  zone_id = data.aws_route53_zone.auto-discovery-zone.zone_id
  name    = "vault.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_vault.dns_name
    zone_id                = aws_elb.elb_vault.zone_id
    evaluate_target_health = true
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
# create jenkins instance
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.vault_key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.profile_jenkins.id

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("./jenkins-userdata.sh", {
    nr-key    = ""
    nr-acc-id = 6496342
  })

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Create IAM role for Jenkins
resource "aws_iam_role" "jenkins_role" {
  name = "${local.name}-jenkins-role"
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
# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "jenkins_role_attachment" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Attach the policy to the role
resource "aws_iam_instance_profile" "profile_jenkins" {
  name = "${local.name}-jenkins-profile"
  role = aws_iam_role.jenkins_role.name

  lifecycle {
    ignore_changes = [role]
  }
}


# Create jenkins security group
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow SSH and HTTPS"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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

# Create elastic Load Balancer for Jenkins
resource "aws_elb" "elb_jenkins" {
  name               = "elb-jenkins"
  security_groups    = [aws_security_group.jenkins_elb_sg.id]
  availability_zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  listener {
    instance_port      = 8080
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate.auto_acm_cert.arn
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8080"
  }
  instances                   = [aws_instance.jenkins_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-jenkins-server"
  }
}
# Create Security group for the jenkins elb
resource "aws_security_group" "jenkins_elb_sg" {
  name        = "${local.name}-jenkins-elb-sg"
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

# Create Route 53 record for jenkins server
resource "aws_route53_record" "jenkins-record" {
  zone_id = data.aws_route53_zone.auto-discovery-zone.zone_id
  name    = "jenkins.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_jenkins.dns_name
    zone_id                = aws_elb.elb_jenkins.zone_id
    evaluate_target_health = true
  }
}
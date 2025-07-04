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
  
#Creating ansible security group
resource "aws_security_group" "ansible-sg" {
  name        = "${var.name}ansible-sg"
  description = "Allow ssh"
  vpc_id      = var.vpc

  ingress {
    description     = "sshport"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-ansible-sg"
  }
}

# IAM User
resource "aws_iam_user" "ansible-user" {
  name = "${var.name}-ansible-user"
}

resource "aws_iam_group" "ansible-group" {
  name = "${var.name}-ansible-group"
    lifecycle {
    create_before_destroy = true
    ignore_changes = [name]
  }
}


resource "aws_iam_access_key" "ansible-user-key" {
  user = aws_iam_user.ansible-user.name
}
resource "aws_iam_user_group_membership" "ansible-group-member" {
  user   = aws_iam_user.ansible-user.name
  groups = [aws_iam_group.ansible-group.name]
}

resource "aws_iam_role_policy_attachment" "ansible-bucket-role-attachment" {
  role       = aws_iam_role.s3-bucket-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
# Create IAM role for Ansible profile
resource "aws_iam_instance_profile" "s3-bucket-instance-profile" {
  name = "${var.name}-s3-bucket-instance-profile"
  role = aws_iam_role.s3-bucket-role.name
}
#create aws iam role for ansible server to access s3 bucket
resource "aws_iam_role" "s3-bucket-role" {
  name = "${var.name}-ansible-s3-bucket-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Create Ansible Server
resource "aws_instance" "ansible_server" {
  ami                    = data.aws_ami.redhat.id #rehat 
  instance_type          = "t2.medium"
  iam_instance_profile   = aws_iam_instance_profile.s3-bucket-instance-profile.name
  vpc_security_group_ids = [aws_security_group.ansible-sg.id]
  key_name               = var.keypair
  subnet_id              = var.subnet_id
  user_data              = local.ansible_userdata
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens = "required"
  }
  tags = {
    Name = "${var.name}-ansible-server"
  }
}

# Create IAM role for ansible
resource "aws_iam_role" "ansible-role" {
  name = "ansible-discovery-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
# Attach the EC2 full access policy to the role
resource "aws_iam_role_policy_attachment" "ec2-policy" {
  role       = aws_iam_role.ansible-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
# Attach S3 full access policy to the role
resource "aws_iam_role_policy_attachment" "s3-policy" {
  role       = aws_iam_role.ansible-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# create a time sleep resource to wait for the ansible server to be up and running
resource "time_sleep" "wait_for_ansible" {
  depends_on = [aws_instance.ansible_server]
  create_duration = "15s"
}
resource "null_resource" "ansible-setup" {
  provisioner "local-exec" {
    command = <<EOT
      aws s3 cp --recursive ${path.module}/script/ s3://chijioke-bucket-auto-discovery/ansible-script/
    EOT
  }
    depends_on = [time_sleep.wait_for_ansible]
}




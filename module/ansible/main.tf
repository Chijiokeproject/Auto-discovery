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


# Create Ansible Server
resource "aws_instance" "ansible-server" {
  ami                    = data.aws_ami.redhat.id #rehat 
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.ansible-sg.id]
  key_name               = var.keypair
  subnet_id              = var.subnet_id
  user_data              = local.ansible_userdata
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  tags = {
    Name = "${var.name}-ansible-server"
  }
}

#Creating ansible secority group
resource "aws_security_group" "ansible-sg" {
  name        = "${var.name}ansible-sg"
  description = "Allow ssh"
  vpc_id      = var.vpc

  ingress {
    description     = "sshport"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg]
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
}

resource "aws_iam_access_key" "ansible-user-key" {
  user = aws_iam_user.ansible-user.name
}

resource "aws_iam_user_group_membership" "ansible-group-member" {
  user   = aws_iam_user.ansible-user.name
  groups = [aws_iam_group.ansible-group.name]
}

resource "aws_iam_group_policy_attachment" "ansible-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  group      = aws_iam_group.ansible-group.name
}
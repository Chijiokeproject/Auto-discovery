locals {
  ansible_userdata = <<-EOF
#!/bin/bash

set -e  # Exit on error

# Update packages and install dependencies
sudo yum update -y
sudo yum install wget unzip -y
sudo bash -c 'echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config'

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
sudo ln -svf /usr/local/bin/aws /usr/bin/aws

# Configure AWS CLI for ec2-user (non-root)
sudo su - ec2-user -c "aws configure set aws_access_key_id ${aws_iam_access_key.ansible-user-key.id}"
sudo su - ec2-user -c "aws configure set aws_secret_access_key ${aws_iam_access_key.ansible-user-key.secret}"
sudo su - ec2-user -c "aws configure set default.region us-west-1"
sudo su - ec2-user -c "aws configure set default.output text"

# Export AWS keys globally (use with caution — only if absolutely needed)
export AWS_ACCESS_KEY_ID=${aws_iam_access_key.ansible-user-key.id}
export AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.ansible-user-key.secret}

# Install Ansible
sudo dnf install -y ansible-core || sudo yum install -y ansible  # Fallback for older AMIs

# Set up SSH key for Ansible user
mkdir -p /home/ec2-user/.ssh
echo "${var.private_key}" > /home/ec2-user/.ssh/id_rsa
chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
chmod 400 /home/ec2-user/.ssh/id_rsa

# Create ansible directory
sudo mkdir -p /etc/ansible

# Pull Ansible scripts from S3
sudo aws s3 cp s3://chijioke-bucket-auto-discovery/ansible-script /etc/ansible --recursive
sudo chmod +x /etc/ansible/*.sh

# Create Ansible vars file
echo "NEXUS_IP: ${var.nexus_ip}:8085" | sudo tee /etc/ansible/ansible_vars_file.yml

# Set permissions for ansible scripts
sudo chown -R ec2-user:ec2-user /etc/ansible
sudo chmod 755 /etc/ansible/prod-bashscript.sh
sudo chmod 755 /etc/ansible/stage-bashscript.sh

# Add cron jobs (ensure crond is running)
echo "* * * * * ec2-user /bin/sh /etc/ansible/prod-bashscript.sh" | sudo tee /etc/cron.d/prod_ansible
echo "* * * * * ec2-user /bin/sh /etc/ansible/stage-bashscript.sh" | sudo tee /etc/cron.d/stage_ansible
sudo chmod 644 /etc/cron.d/prod_ansible /etc/cron.d/stage_ansible
sudo systemctl restart crond

# Install New Relic agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
sudo NEW_RELIC_API_KEY="${var.nr_key}" \
     NEW_RELIC_ACCOUNT_ID="${var.nr_acct_id}" \
     NEW_RELIC_REGION=EU \
     /usr/local/bin/newrelic install -y

# Set hostname
sudo hostnamectl set-hostname ansible-server
EOF
}

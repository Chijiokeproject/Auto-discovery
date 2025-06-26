locals {
  ansible_userdata = <<-EOF
#!/bin/bash

# updating instance
sudo yum update -y
sudo yum install wget unzip -y
sudo bash -c 'echo "StrictHostKeyChecking No" >> /etc/ssh/ssh_config'

# Installing awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo ln -svf /usr/local/bin/aws /usr/bin/aws

# Configuring awscli
# execute cmd as ec2-user
sudo su -c "aws configure set aws_access_key_id ${aws_iam_access_key.ansible-user-key.id}" ec2-user
sudo su -c "aws configure set aws_secret_access_key ${aws_iam_access_key.ansible-user-key.secret}" ec2-user
sudo su -c "aws configure set default.region eu-west-3" ec2-user
sudo su -c "aws configure set default.output text" ec2-user

# Create export variables for access keys
export AWS_ACCESS_KEY_ID=${aws_iam_access_key.ansible-user-key.id}
export AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.ansible-user-key.secret}

# installing ansible
sudo dnf install -y ansible-core
sudo yum update -y

# Copy private key into ansible server /home/ec2-user/.ssh/ dir.
sudo echo "${var.private_key}" > /home/ec2-user/.ssh/id_rsa

#Give permission to copied file
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
sudo chmod 400 /home/ec2-user/.ssh/id_rsa


# Create ansible directory
sudo mkdir -p /etc/ansible



# pulling the ansible scripts and playbook folder from s3 bucket
sudo aws s3 cp s3://${var.s3Bucket}/ansible /etc/ansible --recursive
sudo chmod +x /etc/ansible/*.sh

sleep 10s

# Create ansible hosts file 
sudo bash -c 'echo "NEXUS_IP: ${var.nexus_ip}:8085" > /etc/ansible/ansible_vars_file.yml'

# create premission for ansible scripts
sudo chown -R ec2-user:ec2-user /etc/ansible
sudo chmod 755 /etc/ansible/prod-bashscript.sh
sudo chmod 755 /etc/ansible/stage-bashscript.sh

# Creating cron job using our bash script

echo "* * * * * ec2-user /bin/sh /etc/ansible/prod-bashscript.sh" | sudo tee /etc/crontab
echo "* * * * * ec2-user /bin/sh /etc/ansible/stage-bashscript.sh" | sudo tee -a /etc/crontab

# Install New Relic CLI
# Install New Relic
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${var.nr_key}" NEW_RELIC_ACCOUNT_ID="${var.nr_acct_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y
sudo hostnamectl set-hostname ansible-server
EOF
}
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
sudo su -c "aws configure set default.region eu-west-2" ec2-user
sudo su -c "aws configure set default.output text" ec2-user

# Create export variables for access keys
export AWS_ACCESS_KEY_ID=${aws_iam_access_key.ansible-user-key.id}
export AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.ansible-user-key.secret}

# installing ansible
sudo dnf install -y ansible-core
sudo yum update -y

# Copy private key into ansible server /home/ec2-user/.ssh/ dir.
sudo echo "${var.private-key}" > /home/ec2-user/.ssh/id_rsa

#Give permission to copied file
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
sudo chmod 400 /home/ec2-user/.ssh/id_rsa

# Copying our files to ansible server from our local machine
sudo echo "${file(var.deployment)}" >> /etc/ansible/deployment.yml
sudo echo "${file(var.prod-bashscript)}" >> /etc/ansible/prod-bashscript.sh
sudo echo "${file(var.stage-bashscript)}" >> /etc/ansible/stage-bashscript.sh
sudo bash -c 'echo "NEXUS_IP: ${var.nexus-ip}:8085" > /etc/ansible/ansible_vars_file.yml'
sudo chown -R ec2-user:ec2-user /etc/ansible
sudo chmod 755 /etc/ansible/prod-bashscript.sh
sudo chmod 755 /etc/ansible/stage-bashscript.sh

# Creating cron job using our bash script
echo "* * * * * ec2-user sh /etc/ansible/prod-bashscript.sh" > /etc/crontab
echo "* * * * * ec2-user sh /etc/ansible/stage-bashscript.sh" >> /etc/crontab

# Install New Relic
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${var.nr-key}" NEW_RELIC_ACCOUNT_ID="${var.nr-acc-id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y
sudo hostnamectl set-hostname ansible-server
EOF
}
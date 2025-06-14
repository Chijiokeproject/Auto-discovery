#!/bin/bash
 
#updatng the instance
sudo yum update -y
sudo yum upgrade -y

#install Docker and its dependencies, start Docker service
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo #downloads & adds repo to instance
sudo yum install docker-ce -y
 
 
 
#add a registry to the Docker daemon configuration to allow 
#insecure communication (without TLS verification) with a Docker registry on port 8085
sudo cat <<EOT>> /etc/docker/daemon.json
  {
    "insecure-registries" : ["${nexus-ip}:8085"]
  }
EOT
 
#Starts the Docker service and enables it to run on boot.
#Add the ec2-user to the docker group, allowing them to run Docker commands.
sudo service docker start
sudo systemctl start docker
sudo systemctl enable docker

#add the ec2-user to the docker group, allowing them to run Docker commands.
sudo usermod -aG docker ec2-user
 
#create a shell script that manages a Docker container on the EC2 instance, pulling updates from a Nexus registry
#i.e. Configure docker to fetch image from Nexus
sudo mkdir /home/ec2-user/scripts
cat << EOF > "/home/ec2-user/scripts/script.sh"
#!/bin/bash
 
set -x
 
#Define Variables
IMAGE_NAME="${nexus-ip}:8085/petclinicapps"
CONTAINER_NAME="appContainer"
NEXUS_IP="${nexus-ip}:8085"
 
#Function to Login to dockerhub
authenticate_docker() {
    docker login --username=admin --password=admin123 \$NEXUS_IP
}
 
#Function to check for latest image on dockerhub
check_for_updates() {
    local latest_image=\$(docker pull \$IMAGE_NAME | grep "Status: Image is up to date" | wc -l)
    if [ \$latest_image -eq 0 ]; then
        return 0
    else
        return 1
    fi
}
 
#Function to stop and remove the current container
#Function to deploy image in a container
update_container() {
  docker stop \$CONTAINER_NAME
  docker rm \$CONTAINER_NAME
  docker run -d --name \$CONTAINER_NAME -p 8080:8080 \$IMAGE_NAME
}
 
#Main Function
main() {
    authenticate_docker
    if check_for_updates; then
        update_container
        echo "Container upgraded to latest image."
    else
        echo "Up to date! No image update required. Exiting..."
    fi
}
main
EOF
 
sudo chown -R ec2-user:ec2-user /home/ec2-user/scripts/script.sh
sudo chmod 777 /home/ec2-user/scripts/script.sh
 
#Restart Docker
sudo systemctl restart docker

#Install New Relic CLI, Set hostname for the instance
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${nr-key}" NEW_RELIC_ACCOUNT_ID="${nr-acct-id}" NEW_RELIC_REGION="EU" /usr/local/bin/newrelic install -y

#setting the host name
sudo hostnamectl set-hostname stage-instance
sudo reboot
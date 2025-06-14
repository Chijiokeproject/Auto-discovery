#!/bin/bash
set -x 

#defining our variables
AWSCLI_PATH='/usr/local/bin/aws'
INVENTORY_FILE='/etc/ansible/stage_hosts'
IPS_FILE='/etc/ansible/stage.lists'
ASG_NAME='auto-discovery-stage-asg'
SSH_KEY_PATH='~/.ssh/id_rsa'
WAIT_TIME=20

#write our functions
#fetching the IPs
find_ips() {
    \$AWSCLI_PATH ec2 describe-instances \\
    --filters "Name=tag:aws:autoscaling:groupName,Values=\$ASG_NAME" \\
    --query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddress' \\
    --output text > "\$IPS_FILE"
}
#update the inventory files
update_inventory() {
    echo "[webservers]" > "\$INVENTORY_FILE" 
    while IFS= read -r instance; do
        ssh-keyscan -H "\$instance" >> ~/.ssh/known_hosts
        echo "\$instance ansible_user=ec2-user" >> "\$INVENTORY_FILE"
    done < "\$IPS_FILE"
    echo "Inventory updated succesfully"
}
#wait for some minutes
wait_for_seconds() {
    echo "Waiting for \$WAIT_TIME seconds..."
    sleep "\$WAIT_TIME"
}
# check if the docker container is running on all the instances in the ips file by sshing into them one by one, 
# if container is not running on the instance, then execute a script /home/ec2-user/scripts.sh to start the container
check_docker_container() {
    while IFS= read -r instance; do
        ssh -i "\$SSH_KEY_PATH" ec2-user@"\$instance" "docker ps | grep appContainer" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Container not running on \$instance. Starting container..."
            ssh -i "\$SSH_KEY_PATH" ec2-user@"\$instance" "bash /home/ec2-user/scripts/script.sh"
        else
            echo "Container is running on \$instance."
        fi
    done < "\$IPS_FILE"
}
# Main function block
main() {
    find_ips
    update_inventory
    wait_for_seconds
    check_docker_container
}
# Execute main function
main

### End of script
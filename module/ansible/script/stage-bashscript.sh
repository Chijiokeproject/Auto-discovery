#!/bin/bash
set -x 

# Define variables
AWSCLI_PATH='/usr/local/bin/aws'
INVENTORY_FILE='/etc/ansible/stage_hosts'
IPS_FILE='/etc/ansible/stage.lists'
ASG_NAME='auto-discovery-stage-asg'
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
WAIT_TIME=20

# Function to find instance IPs
find_ips() {
    $AWSCLI_PATH ec2 describe-instances \
        --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
        --query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddress' \
        --output text > "$IPS_FILE"
}

# Function to update Ansible inventory
update_inventory() {
    echo "[webservers]" > "$INVENTORY_FILE" 
    while IFS= read -r instance; do
        ssh-keyscan -H "$instance" >> ~/.ssh/known_hosts
        echo "$instance ansible_user=ec2-user" >> "$INVENTORY_FILE"
    done < "$IPS_FILE"
    echo "Inventory updated successfully"
}

# Function to wait
wait_for_seconds() {
    echo "Waiting for $WAIT_TIME seconds..."
    sleep $WAIT_TIME
}

# Function to check if Docker container is running
check_docker_container() {
    while IFS= read -r instance; do
        ssh -i "$SSH_KEY_PATH" ec2-user@"$instance" "docker ps | grep appContainer" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Container not running on $instance. Starting container..."
            ssh -i "$SSH_KEY_PATH" ec2-user@"$instance" "bash /home/ec2-user/scripts/script.sh"
        else
            echo "Container is running on $instance."
        fi
    done < "$IPS_FILE"
}

# Main execution
main() {
    find_ips
    update_inventory
    wait_for_seconds
    check_docker_container
}
main

# Execute main function
main

### End of script
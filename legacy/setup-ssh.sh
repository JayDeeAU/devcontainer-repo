#!/bin/bash

# This script sets up SSH for the dev container

# Ensure the .ssh directory exists with correct permissions
sudo mkdir -p /home/joe/.ssh
sudo chown joe:joe /home/joe/.ssh
sudo chmod 700 /home/joe/.ssh

# Generate SSH keys if they do not exist
if [ ! -f /home/joe/.ssh/id_rsa ]; then
    sudo -u joe ssh-keygen -t rsa -b 4096 -f /home/joe/.ssh/id_rsa -N ""
fi

# Ensure the known_hosts file exists with correct permissions
sudo touch /home/joe/.ssh/known_hosts
sudo chown joe:joe /home/joe/.ssh/known_hosts
sudo chmod 644 /home/joe/.ssh/known_hosts

# Copy the public key to the host's authorized_keys if not already present
PUB_KEY=$(cat /home/joe/.ssh/id_rsa.pub)

if ! ssh -o StrictHostKeyChecking=no ${SSH_HOST_ENDPOINT} "grep -q \"$PUB_KEY\" ~/.ssh/authorized_keys"; then
    ssh -o StrictHostKeyChecking=no ${SSH_HOST_ENDPOINT} "echo \"$PUB_KEY\" >> ~/.ssh/authorized_keys"
fi

# Set appropriate permissions for the keys
sudo chown joe:joe /home/joe/.ssh/id_rsa /home/joe/.ssh/id_rsa.pub
sudo chmod 600 /home/joe/.ssh/id_rsa
sudo chmod 644 /home/joe/.ssh/id_rsa.pub
echo "SSH setup completed. Keys are generated and copied to the host."
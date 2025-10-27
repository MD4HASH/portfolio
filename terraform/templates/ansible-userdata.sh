#!/bin/bash
set -xe

# Redirect logs
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update packages
apt-get update -y
apt-get upgrade -y

# Install dependencies
apt-get install -y git python3 python3-pip

# Ensure pip path
export PATH=$PATH:/usr/local/bin

# Install Ansible
pip3 install --upgrade ansible

# Clone the repo root
git clone ${ansible_repo_url} /home/ubuntu/ansible-repo

# Go into the ansible subfolder
cd /home/ubuntu/ansible-repo/ansible

# Run the playbook
ansible-playbook playbook.yml -i localhost, --connection=local

# Fix permissions
chown -R ubuntu:ubuntu /home/ubuntu/ansible-repo

#!/bin/bash
# Update packages
yum update -y

# Install required packages
yum install -y git python3 python3-pip

# Install Ansible
pip3 install ansible --upgrade

# Clone your repo (replace with var.ansible_repo_url in Terraform)
git clone ${ansible_repo_url} /home/ec2-user/ansible-repo

# Run the main playbook
cd /home/ec2-user/ansible-repo
ansible-playbook main.yml -i inventory.yml

# Optional: set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/ansible-repo

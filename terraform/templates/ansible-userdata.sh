#!/bin/bash
set -xe

# Redirect logs
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Install Python 3.11, venv, and pip
apt-get update -y
apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip git wget build-essential

# Create a virtual environment for Ansible and WebUI
python3.11 -m venv /home/ubuntu/webui-venv
source /home/ubuntu/webui-venv/bin/activate

# Upgrade pip and install Ansible
pip install --upgrade pip setuptools wheel ansible

# Clone the repo root 
git clone ${ansible_repo_url} /home/ubuntu/ansible-repo

# Install Ansible in the venv 
sudo apt install ansible -y

# Run the Ansible playbook from the ansible-repo
cd /home/ubuntu/ansible-repo/ansible
ANSIBLE_PYTHON_INTERPRETER=/home/ubuntu/webui-venv/bin/python \
ansible-playbook playbook.yml -i localhost, --connection=local

# Fix permissions on the repo
chown -R ubuntu:ubuntu /home/ubuntu/ansible-repo

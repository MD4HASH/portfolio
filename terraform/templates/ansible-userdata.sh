#!/bin/bash
set -xe

# Redirect logs
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update packages
apt-get update -y
apt-get upgrade -y

# Install dependencies
apt-get install -y git wget build-essential python3.11 python3.11-venv python3.11-dev python3-pip

# Ensure pip path
export PATH=$PATH:/usr/local/bin

# Upgrade pip for Python 3.11
python3.11 -m ensurepip --upgrade
python3.11 -m pip install --upgrade pip setuptools wheel

# Create a virtual environment for Ansible and WebUI
python3.11 -m venv /home/ubuntu/webui-venv
source /home/ubuntu/webui-venv/bin/activate

# Install Ansible in the venv
pip install --upgrade ansible

# Clone the repo root
git clone ${ansible_repo_url} /home/ubuntu/ansible-repo

# Go into the ansible subfolder
cd /home/ubuntu/ansible-repo/ansible

# Run the playbook using the venv Python
ANSIBLE_PYTHON_INTERPRETER=/home/ubuntu/webui-venv/bin/python \
ansible-playbook playbook.yml -i localhost, --connection=local

# Fix permissions
chown -R ubuntu:ubuntu /home/ubuntu/ansible-repo

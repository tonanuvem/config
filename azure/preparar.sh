#!/bin/bash

# Tamanho da VM: Standard_B2as_v2

sudo apt-get -y update
sudo apt-get install -y git python3 pip apache2 unzip zip
pip3 install --upgrade pip
sudo python3 -m pip install ansible

echo "\n\n Configurar pre-req para instalação do Ansible"
# configurar pre-req (inventario) ansible
export VM=$(curl -s checkip.amazonaws.com)
echo '[nodes]' > ~/environment/config/hosts
echo "local ansible_connection=local" >> ~/environment/config/hosts
echo '' >> ~/environment/config/hosts
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

echo "\n\n Configurando com Ansible"
ansible-playbook ~/environment/config/ansible/azure-vm.yml --inventory ~/environment/config/hosts 
  #-u ubuntu --key-file ~/environment/labsuser.pem

echo "\n\n Configurando Cloud9 com Spring"
bash ~/environment/config/spring.sh


## FIM
#source ~/.bash_profile
echo ""
echo "  FIM!! Ambiente foi configurado!"
echo ""

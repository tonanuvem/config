#!/bin/bash

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

echo " Liberando firewall para o ambiente"
if [ $(aws ec2 describe-security-groups | jq '.SecurityGroups[] | select(.GroupName | contains("cloud9")) | .GroupName' | wc -l) = "1" ]
then
  # liberar firewall automaticamente se só existe 1 security group
  NOME_GRUPO_SEGURANCA=$(aws ec2 describe-security-groups | jq '.SecurityGroups[] | select(.GroupName | contains("cloud9")) | .GroupName' | tr -d \")
  aws ec2 authorize-security-group-ingress --group-name $NOME_GRUPO_SEGURANCA --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
else
  # escolher manualmente dentre os securty groups existentes
  bash ~/environment/config/firewall_allow.sh
fi


## FIM
#source ~/.bash_profile
echo ""
echo "  FIM!! Cloud9 foi configurado!"
echo ""

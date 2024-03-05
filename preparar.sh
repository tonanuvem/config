#!/bin/bash

echo " Aumentando o tamanho do disco para 100G, podem aparecer Warnings"
# aumentando o disco para 100G e 
sh ~/environment/config/resize.sh 100 > /dev/null

echo " Liberando firewall para o ambiente do Cloud9"
if [ $(aws ec2 describe-security-groups | jq '.SecurityGroups[] | select(.GroupName | contains("cloud9")) | .GroupName' | wc -l) = "1" ]
then
  # liberar firewall automaticamente se só existe 1 security group
  NOME_GRUPO_SEGURANCA=$(aws ec2 describe-security-groups | jq '.SecurityGroups[] | select(.GroupName | contains("cloud9")) | .GroupName' | tr -d \")
  aws ec2 authorize-security-group-ingress --group-name $NOME_GRUPO_SEGURANCA --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
else
  # escolher manualmente dentre os securty groups existentes
  bash ~/environment/config/firewall_allow.sh
fi
#sh ~/environment/config/resize.sh 100 > /dev/null

echo "\n\n Configurar pre-req para instalação do Ansible"
# configurar pre-req (inventario) ansible
export VM=$(curl -s checkip.amazonaws.com)
echo '[nodes]' > ~/environment/config/hosts
echo "localhost ansible_connection=local" >> ~/environment/config/hosts
#echo "cloud9 ansible_ssh_host=$VM" >> ~/environment/config/hosts
echo '' >> ~/environment/config/hosts
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

# verificar o tamanho do disco
printf "\n\tVERIFICA O TAMANHO DO DISCO :\n"
if [ $(df -mh | grep 97G | wc -l) = "1" ]
then
  printf "\t\tDISCO OK!\n"
  sh ansible.sh
else
  echo "\t\tTamanho do disco talvez seja insuficiente. (em caso de erro, executar: \"sh ~/environment/config/resize.sh 100\")"
  exit
fi

echo "\n\n Configurar Cloud9 com Ansible"
ansible-playbook ~/environment/config/ansible/cloud9.yml --inventory hosts 
  #-u ubuntu --key-file ~/environment/labsuser.pem

ansible-playbook ~/environment/config/ansible/ansible_verificar.yml --inventory hosts

## FIM
source ~/.bash_profile

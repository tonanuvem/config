#!/bin/bash

# mkdir ~/environment/

echo "\n\n Ajustando permissão do arquivo labsuser.pem"
# verificar o tamanho do disco
printf "\n\tVERIFICANDO ARQUIVO DE CHAVE labsuser.pem :\n\n"
if [ $(ls ~/environment/ | grep labsuser.pem | wc -l) = "1" ]
then
  printf "\t\tARQUIVO labsuser.pem OK!\n\n"
  chmod 400 ~/environment/labsuser.pem
else
  echo "\t\tArquivo labsuser.pem não encontrado, você deve fazer o upload do arquivo para o Cloud9\n\n"
  exit
fi

### ANSIBLE
#bash ~/environment/config/ansible.sh
sudo apt-get update
sudo apt install -y python3-pip
pip3 install --upgrade pip
sudo python3 -m pip install ansible --break-system-packages
printf "\n\tANSIBLE:\n"
ansible --version

### APACHE
sudo apt install -y apache2
sudo ufw allow 'Apache'
sudo ufw status
#sudo systemctl status apache2

### UTILS: unzip
sudo apt install -y unzip zip

echo "\n\n Configurar pre-req para instalação do Ansible"
# configurar pre-req (inventario) ansible
export VM=$(curl -s checkip.amazonaws.com)
echo '[nodes]' > ~/environment/config/hosts
echo "codeserver ansible_connection=local" >> ~/environment/config/hosts

echo '' >> ~/environment/config/hosts
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

echo "\n\n Configurando CodeServer com Ansible"
ansible-playbook ~/environment/config/ansible/cloud9.yml --inventory ~/environment/config/hosts 
  #-u ubuntu --key-file ~/environment/labsuser.pem

echo "\n\n Configurando Cloud9 com Spring"
bash ~/environment/config/spring.sh

echo " Liberando firewall para o ambiente do CodeServer"
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
echo "  FIM!! CodeServer foi configurado!"
echo ""

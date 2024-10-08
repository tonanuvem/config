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
#sudo ufw status
#sudo systemctl status apache2

### UTILS: 
# UNZIP, ZIP
sudo apt install -y unzip zip
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf ~/environment/credentials
ln -s ~/environment/credentials ~/.aws/credentials 

### CODE SERVER:
curl -fsSL https://code-server.dev/install.sh | sh
sudo systemctl enable --now code-server@$USER
# https://coder.com/docs/code-server/guide#using-a-self-signed-certificate
# Replaces "cert: false" with "cert: true" in the code-server config.
sed -i.bak 's/cert: false/cert: true/' ~/.config/code-server/config.yaml
# Replaces "bind-addr: 127.0.0.1:8080" with "bind-addr: 0.0.0.0:443" in the code-server config.
sed -i.bak 's/bind-addr: 127.0.0.1:8080/bind-addr: 0.0.0.0:443/' ~/.config/code-server/config.yaml
# Replaces "bind-addr: 127.0.0.1:8080" with "bind-addr: 0.0.0.0:443" in the code-server config.
sed -i.bak 's/password: .*/password: fiap/g' ~/.config/code-server/config.yaml
# Allows code-server to listen on port 443.
sudo setcap cap_net_bind_service=+ep /usr/lib/code-server/lib/node
#sudo systemctl enable --now code-server@$USER
sudo systemctl restart code-server@$USER
#sudo systemctl status code-server

# settings.json : Code Server
mkdir ~/.local/share/code-server/User/
cat >> ~/.local/share/code-server/User/settings.json <<EOL
{
    "workbench.colorTheme": "Default Dark Modern"
}
EOL

# utils: cria script para verificar ip publico.
sudo cat >> ~/ip <<EOL
curl checkip.amazonaws.com
EOL
chmod +x ~/ip

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

## FIM
#source ~/.bash_profile
echo ""
echo "  FIM!! CodeServer foi configurado!"
echo ""

#!/bin/bash

echo "\n\n Ajustando as pastas do CloudShell e a permissão do arquivo labsuser.pem"

## Retrieve AWS credentials from AWS CloudShell : aws-cloud-shell-get-aws-credentials.sh
# https://gist.github.com/dclark/b014ac10540ca2d6911c643b8956fc50

# shellcheck disable=SC2001
HOST=$(echo "$AWS_CONTAINER_CREDENTIALS_FULL_URI" | sed 's|/latest.*||')
TOKEN=$(curl -s -X PUT "$HOST"/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
OUTPUT=$(curl -s "$HOST/latest/meta-data/container/security-credentials" -H "X-aws-ec2-metadata-token: $TOKEN")
echo "[default]" > ~/credentials
echo "AWS_ACCESS_KEY_ID=$(echo "$OUTPUT" | jq -r '.AccessKeyId')" >> ~/credentials
echo "AWS_SECRET_ACCESS_KEY=$(echo "$OUTPUT" | jq -r '.SecretAccessKey')" >> ~/credentials
echo "AWS_SESSION_TOKEN=$(echo "$OUTPUT" | jq -r '.Token')" >> ~/credentials
echo "region=us-east-1" >> ~/credentials


# INICIANDO COMENTARIO
#: <<'END'
printf "\n\tVERIFICANDO ARQUIVO DE CHAVE labsuser.pem :\n\n"
if [ $(ls ~ | grep config | wc -l) = "1" ]
then
  mkdir ~/environment/
  mv  ~/config ~/environment/config
  cp  ~/credentials ~/environment/
else
  echo "\t\Pasta CONFIG não encontrada, você deve  rodar o comando git clone na pasta raiz\n\n"
  #exit
fi

if [ $(ls ~ | grep labsuser.pem | wc -l) = "1" ]
then
  printf "\t\tARQUIVO labsuser.pem OK!\n\n"
  mkdir ~/environment/
  cp  ~/labsuser.pem ~/environment/labsuser.pem
  chmod 400 ~/environment/labsuser.pem
  #sh ~/environment/config/preparar.sh
else
  echo "\t\tArquivo labsuser.pem não encontrado, você deve fazer o upload do arquivo para o CloudShell\n\n"
  #exit
fi

if [ $(ls ~ | grep credentials | wc -l) = "1" ]
then
  echo "\n\n Configurar pre-req para instalação do Ansible"
  # configurar pre-req (inventario) ansible
  #export VM=$(curl -s checkip.amazonaws.com)
  echo '[nodes]' > ~/environment/config/hosts
  echo "cloud9 ansible_connection=local" >> ~/environment/config/hosts
  #echo "cloud9 ansible_ssh_host=$VM" >> ~/environment/config/hosts
  echo '' >> ~/environment/config/hosts
  export ANSIBLE_PYTHON_INTERPRETER=auto_silent
  export ANSIBLE_DEPRECATION_WARNINGS=false
  export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
else
  echo "\t\tArquivo credentials não encontrado, você deve reiniciar o CloudShell\n\n"
  #exit
fi

#FINALIZANDO COMENTARIO
#END

# CRIAR UBUNTU VM DO CODESERVER
# https://docs.aws.amazon.com/cli/v1/userguide/cli-services-ec2-instances.html

#sh terraform.sh
if [ $(ls ~ | grep terraform | wc -l) = "1" ]
then
  sudo cp terraform /usr/bin/
else
  # Atualizar versao do Terraform: 
  printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
  printf "\n\n\tTerraform:\n\n"
  curl -s "https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip" -o "terraform_linux_amd64.zip"
  unzip terraform_linux_amd64.zip
  sudo cp terraform /usr/bin/
  rm -rf terraform_linux_amd64.zip LICENSE
fi

# Verificando as versões instaladas e atualizar permissão docker:
cd ~
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tVerificando as instações:\n\n"

printf "\n\tTERRAFORM:\n"
terraform --version

cd ~/environment/config/ubuntu-vm/
sh iniciar.sh 

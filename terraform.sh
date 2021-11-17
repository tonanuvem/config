#!/bin/bash

# Atualizar versao do Terraform: 
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tTerraform:\n\n"
curl -s "https://releases.hashicorp.com/terraform/1.0.11/terraform_1.0.11_linux_amd64.zip" -o "terraform_linux_amd64.zip"
unzip terraform_linux_amd64.zip
sudo mv terraform /usr/bin/

# Verificando as versões instaladas e atualizar permissão docker:
cd ~
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tVerificando as instações:\n\n"

printf "\n\tTERRAFORM:\n"
terraform --version

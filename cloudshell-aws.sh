#!/bin/bash

# para executar o script, rodar: 
# curl -s https://raw.githubusercontent.com/tonanuvem/config/refs/heads/main/cloudshell-aws.sh | bash && cd ~/environment/config

# CONFIG provider ----------
#	Configurar Terraform
# sh terraform.sh

# CONFIG environment ----------

# Caminho da pasta
PASTA_ENV="$HOME/environment"
PASTA_CONFIG="$PASTA_ENV/config"

# Verifica se a pasta 'environment' existe
if [ ! -d "$PASTA_ENV" ]; then
    echo "Criando pasta '$PASTA_ENV'..."
    mkdir -p "$PASTA_ENV"
fi

# Verifica se a pasta 'config' existe dentro de 'environment'
if [ ! -d "$PASTA_CONFIG" ]; then
    echo "Clonando repositório na pasta '$PASTA_ENV'..."
    git clone https://github.com/tonanuvem/config "$PASTA_CONFIG"
    echo -e 'cd ~/environment/config/vm-fiap/ && terraform init; terraform plan; terraform apply -auto-approve' > ~/iniciar.sh 
    echo -e 'cd ~/environment/config/vm-fiap/ && terraform destroy -auto-approve' > ~/destruir.sh
else
    echo "A pasta '$PASTA_CONFIG' já existe."
fi

# Entrar no diretório ~/enviroment/config
echo ""
echo ""
echo "📁  Pasta configurada. "
echo "                        cd ~/environment/config"
echo ""
# Entrar no diretório ~/enviroment/config
echo ""
echo ""
echo "📁  Configurando o Terraform. "
cd ~/environment/config
echo ""
echo ""
sh ~/environment/config/terraform.sh
echo ""
echo ""
echo "📁  Aumentando o tamanho do disco para 100G, podem aparecer Warnings\n\n"
# aumentando o disco para 100G e 
sh ~/environment/config/resize.sh 100 > /dev/null
echo ""
echo ""
echo "📁  Configurando pre-req para instalação do Ansible"
# configurar pre-req (inventario) ansible
export VM=$(curl -s checkip.amazonaws.com)
echo '[nodes]' > ~/environment/config/hosts
echo "cloudshell ansible_connection=local" >> ~/environment/config/hosts
echo '' >> ~/environment/config/hosts
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
echo ""
echo ""
echo "📁  Configurando Ansible"
# verificar o tamanho do disco
printf "\n\tVERIFICANDO O TAMANHO DO DISCO :\n\n"
if [ $(df -mh | grep 97G | wc -l) = "1" ]
then
  printf "\t\tDISCO OK!\n\n"
  bash ~/environment/config/ansible.sh
else
  echo "\t\tTamanho do disco talvez seja insuficiente. (em caso de erro, executar: \"sh ~/environment/config/resize.sh 100\")"
  exit
fi

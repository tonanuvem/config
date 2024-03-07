#!/bin/bash

# Verificando as versões instaladas e atualizar permissão docker:
cd ~
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tVerificando as instações:\n\n"
printf "\n\n\tDEV TOOLS:\n\n"
printf "\n\tJAVA:\n"
java -version
javac -version
#printf "\n\tMAVEN:\n"
#mvn -version
printf "\n\tSPRING:\n"
spring --version
printf "\n\tPYTHON:\n"
python3 --version
printf "\n\tPIP:\n"
pip3 --version
printf "\n\n\tOPS TOOLS:\n\n"
printf "\n\tDOCKER:\n"
sudo docker version
docker-compose --version
printf "\n\tAWSCLI:\n"
aws --version
# nao usando no momento:
#printf "\n\tElastic Beanstalker CLI:\n"
#export PATH="/home/ubuntu/.ebcli-virtual-env/executables:$PATH"
#export PATH=/home/ubuntu/.pyenv/versions/3.7.2/bin:$PATH
#eb --version
printf "\n\tTERRAFORM:\n"
terraform --version
#printf "\n\tANSIBLE:\n"
#ansible --version
printf "\n\tMINIKUBE:\n"
minikube version
printf "\n\tKUBECTL:\n"
kubectl version --client
printf "\n\tHELM:\n"
helm version -c
printf "\n\tEXIBE DISCO :\n"
df -mh | grep dev
#liberando acesso externo
printf "\n\tAPLICANDO ULTIMAS CONFIGURAÇÕES:\n"
#sudo apt-get -y install jq > /dev/null

#sh ~/environment/config/pacotes.sh

printf "\n\tMAVEN:\n"
mvn -version

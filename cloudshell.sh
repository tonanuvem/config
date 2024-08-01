#!/bin/bash

echo "\n\n Ajustando as pastas do CloudShell e a permissão do arquivo labsuser.pem"

printf "\n\tVERIFICANDO ARQUIVO DE CHAVE labsuser.pem :\n\n"
if [ $(ls ~ | grep config | wc -l) = "1" ]
then
  mkdir ~/environment/
  mv  ~/config ~/environment/config
else
  echo "\t\Pasta CONFIG não encontrada, você deve fazer rodar o comando git clone na pasta raiz\n\n"
  exit
fi

if [ $(ls ~ | grep labsuser.pem | wc -l) = "1" ]
then
  printf "\t\tARQUIVO labsuser.pem OK!\n\n"
  mv  ~/labsuser.pem ~/environment/labsuser.pem
  chmod 400 ~/environment/labsuser.pem
  sh ~/environment/config/preparar.sh
else
  echo "\t\tArquivo labsuser.pem não encontrado, você deve fazer o upload do arquivo para o CloudShell\n\n"
  exit
fi


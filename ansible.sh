#!/bin/bash
# verificar o tamanho do disco

if [ $(df -mh | grep 97G | wc -l) = "1" ]
then
  pip3 install --upgrade pip
  sudo python3 -m pip install ansible

  printf "\n\tANSIBLE:\n"
  ansible --version
else
  echo "Tamanho do disco insuficiente. Execute o comando a seguir e tente novamente: sh resize.sh"
  exit
fi

#!/bin/bash
# verificar o tamanho do disco

if [ $(df -mh | grep G | awk '{print $2}') = "97G" ]
then
  sudo python3 -m pip install ansible

  printf "\n\tANSIBLE:\n"
  ansible --version
else
  echo "Tamanho do disco insuficiente. Execute o comando a seguir e tente novamente: sh resize.sh"
  exit
fi

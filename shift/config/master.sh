#!/bin/bash

printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tMASTER: configurando hostname\n\n"

echo ""
echo "   Aguardando configurações: "
sleep 1
IP=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_0/) ) { print $1} }')
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO" | grep CONECTADO | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
ssh -o LogLevel=error -i ~/environment/labsuser.pem ec2-user@$IP "while [ \$(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done"

ssh -o LogLevel=error -i "~/environment/labsuser.pem" ubuntu@$IP "sudo hostnamectl set-hostname master"
echo "   Configuração MASTER OK."

#!/bin/bash

printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tNODE 3: configurando hostname\n\n"

echo ""
echo "   Aguardando configurações: "
sleep 1
export IP=$(terraform output -raw Node_3_ip_externo)
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO" | grep CONECTADO | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
ssh -o LogLevel=error -i ~/environment/labsuser.pem ec2-user@$IP "while [ \$(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done"

ssh -o LogLevel=error -i "~/environment/labsuser.pem" ubuntu@$IP "sudo hostnamectl set-hostname node3"
echo "   Configuração NODE 3 OK."

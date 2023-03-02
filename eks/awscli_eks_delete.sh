#!/bin/bash

# Configurando as variaveis
if [ -f "./awscli/VPC_ID.txt" ]; then 
    echo "Arquivo VPC_ID.txt encontrado"
else 
    echo "VPC_ID.txt nao encontrado"; 
    exit
fi

VPC_ID=$(cat ./awscli/VPC_ID.txt)
echo $VPC_ID

SUBNET_1_ID=$(cat ./awscli/SUBNET_1_ID.txt)
echo $SUBNET_1_ID

SUBNET_2_ID=$(cat ./awscli/SUBNET_2_ID.txt)
echo $SUBNET_2_ID

SECURITYGROUP_ID=$(cat ./awscli/SECURITYGROUP_ID.txt)
echo $SECURITYGROUP_ID

ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

# Removendo

aws eks delete-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap
echo "Excluindo o Cluster EKS e seus Workers"
while [ $(aws eks describe-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap --query 'nodegroup.status' --output text | grep DELETING | wc -l) != '0' ]; do { printf .; sleep 1; } done
aws eks delete-cluster --name eksfiap
while [ $(aws eks describe-cluster --name eksfiap --query 'cluster.status' --output text | grep DELETING | wc -l) != '0' ]; do { printf .; sleep 1; } done
aws ec2 delete-security-group --group-id $SECURITYGROUP_ID
aws ec2 delete-subnet --subnet-id $SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $SUBNET_2_ID
aws ec2 delete-vpc --vpc-id $VPC_ID

# Movendo a pasta com as configurações antigas:

echo "Todos os comandos anteriores foram executados com SUCESSO ? Se sim: digitar 0 e apertar ENTER"
read ERRO

if [ $ERRO -eq 0 ]; 
then 
    echo "Ambiente EKS excluido" 
    mv "./awscli" "./bkp_awscli_$(date "+%Y_%m_%d_%Hh%Mm%S")"
else 
    echo "Tente rodar novamente o comando: sh awscli_eks_delete.sh" 
fi




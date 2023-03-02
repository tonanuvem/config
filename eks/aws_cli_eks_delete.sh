#!/bin/bash

# Configurando as variaveis
if [[ -f "./awscli/VPC_ID_EKS.txt" && -s "./awscli/VPC_ID_EKS.txt" ]]; then 
    echo "Arquivo VPC_ID_EKS.txt encontrado"
else 
    echo "VPC_ID_EKS.txt nao encontrado"; 
    exit
fi

VPC_ID=$(cat ./awscli/VPC_ID_EKS.txt)
echo $VPC_ID

SUBNET_1_ID=$(cat ./awscli/SUBNET_1_ID.txt)
echo $SUBNET_1_ID

SUBNET_2_ID=$(cat ./awscli/SUBNET_2_ID.txt)
echo $SUBNET_2_ID


# Removendo

aws eks delete-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap
aws eks delete-cluster --name eksfiap
aws ec2 delete-security-group --group-id $SECURITYGROUP_ID
aws ec2 delete-subnet --subnet-id $SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $SUBNET_2_ID
aws ec2 delete-vpc --vpc-id $VPC_ID

# Apagando a pasta com as configurações:

rm -rf ./awscli

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
aws eks delete-cluster --name eksfiap
aws ec2 delete-security-group --group-id $SECURITYGROUP_ID
aws ec2 delete-subnet --subnet-id $SUBNET_1_ID
aws ec2 delete-subnet --subnet-id $SUBNET_2_ID
aws ec2 delete-vpc --vpc-id $VPC_ID

# Movendo a pasta com as configurações antigas:

mv "./awscli" "./bkp_awscli_$(date "+%Y_%m_%d_%Hh%Mm%S")"


#!/bin/bash

# https://blog.devgenius.io/how-to-create-eks-cluster-using-aws-cli-60e41111940b

# Configurando as variaveis
if [ -f "./awscli/" ]; then 
    echo "Configuração anterior encontrada"
    echo "Primeiro destrua o ambiente antigo:  sh aws_cli_eks_delete.sh"
else 
    mkdir ./awscli
fi

# Criar o VPC

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.6.0.0/16 --query Vpc.VpcId --output text)

echo ""
echo "Criado o VPC : $VPC_ID"
echo $VPC_ID >> ./awscli/VPC_ID.txt
echo ""

# Criar as subredes

SUBNET_1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.6.1.0/24 --availability-zone us-east-1a --query Subnet.SubnetId --output text)
echo "Criado o Subnet 1 : $SUBNET_1_ID"
echo $SUBNET_1_ID >> ./awscli/SUBNET_1_ID.txt
SUBNET_2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.6.2.0/24 --availability-zone us-east-1b --query Subnet.SubnetId --output text)
echo "Criado o Subnet 2 : $SUBNET_2_ID"
echo $SUBNET_2_ID >> ./awscli/SUBNET_2_ID.txt


# Criar as regras de firewall

SECURITYGROUP_ID=$(aws ec2 create-security-group --group-name eks-sg-node-group --description "EKS Node Group" --vpc-id $VPC_ID --query GroupId --output text)

aws ec2 authorize-security-group-ingress --group-id $SECURITYGROUP_ID --protocol "all" --cidr "0.0.0.0/0"
#aws ec2 authorize-security-group-ingress --group-id $SECURITYGROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 
#aws ec2 authorize-security-group-ingress --group-id $SECURITYGROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 
#aws ec2 authorize-security-group-ingress --group-id $SECURITYGROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0

echo ""
echo "Criadas as regras de firewall : $SECURITYGROUP_ID"
echo $SECURITYGROUP_ID >> ./awscli/SECURITYGROUP_ID.txt
echo ""

# Criar o Cluster EKS

ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

echo ""
echo "Role ARN do Lab : $ROLE_ARN"
echo ""

aws eks create-cluster --name eksfiap --role-arn $ROLE_ARN --resources-vpc-config subnetIds=$SUBNET_1_ID,$SUBNET_2_ID,securityGroupIds=$SECURITYGROUP_ID

# Aguardando

aws eks describe-cluster --name eksfiap
echo ""
echo "Aguardando a criação do Cluster EKS (Tempo estimado = 7 minutos)"
aws eks describe-cluster --name eksfiap --query 'cluster.status' --output text

for tempo in $(seq 1 100); do { echo -ne "$tempo%\033[0K\r"; sleep 4; } done
while [ $(aws eks describe-cluster --name eksfiap --query 'cluster.status' --output text | grep ACTIVE | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Cluster criado!"
echo ""
echo "   Masters estão criados. Agora vamos criar os Workers..."
echo ""



# Criar os Nodes Workers

aws eks create-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap --scaling-config minSize=1,maxSize=4,desiredSize=2 --subnets $SUBNET_1_ID $SUBNET_2_ID --remote-access ec2SshKey=vockey,sourceSecurityGroups=$SECURITYGROUP_ID --instance-types t3.medium --node-role $ROLE_ARN

aws eks describe-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap
echo ""
echo "Aguardando a criação dos Workers (Tempo estimado = 5 minutos)"
aws eks describe-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap --query 'nodegroup.status' --output text

for tempo in $(seq 1 100); do { echo -ne "$tempo%\033[0K\r"; sleep 3; } done
while [ $(aws eks describe-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap --query 'nodegroup.status' --output text | grep ACTIVE | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Nodes Workers criados!"


# Update Kubeconfig file

aws eks update-kubeconfig --region us-east-1 --name eksfiap

kubectl cluster-info

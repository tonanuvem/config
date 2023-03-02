# https://blog.devgenius.io/how-to-create-eks-cluster-using-aws-cli-60e41111940b

mkdir ./awscli

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
aws eks describe-cluster --name eksfiap
echo "Aguardando a criação do Cluster EKS"
aws eks describe-cluster --name eksfiap --query 'cluster.status' --output text
while [ $(aws eks describe-cluster --name eksfiap --query 'cluster.status' --output text | grep ACTIVE | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Cluster criado! "


# Criar os Nodes

aws eks create-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap --scaling-config minSize=1,maxSize=4,desiredSize=2 --subnets $SUBNET_1_ID,$SUBNET_2_ID --remote-access ec2SshKey=vockey,sourceSecurityGroups=$SECURITYGROUP_ID --instance-types t3.medium --node-role $ROLE_ARN
# --ami-type AL2_x86_64
aws eks describe-nodegroup --cluster-name eksfiap --nodegroup-name workers_eksfiap


# Update Kubeconfig file

aws eks update-kubeconfig --region us-east-1 --name eksfiap

kubectl cluster-info

# https://blog.devgenius.io/how-to-create-eks-cluster-using-aws-cli-60e41111940b

# Criar o VPC

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.5.0.0/16 --query Vpc.VpcId --output text)

echo "Criado o VPC : $VPC_ID"


# Criar as subredes

aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.5.1.0/24 --availability-zone us-east-1a 
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.5.2.0/24 --availability-zone us-east-1a


# Criar as regras de firewall

aws ec2 create-security-group --group-name eks-node-group --description "EKS Node Group" --vpc-id $VPC_ID

aws ec2 authorize-security-group-ingress --group-id <group-id> --protocol tcp --port 22 --cidr 0.0.0.0/0 
aws ec2 authorize-security-group-ingress --group-id <group-id> --protocol tcp --port 80 --cidr 0.0.0.0/0 
aws ec2 authorize-security-group-ingress --group-id <group-id> --protocol tcp --port 443 --cidr 0.0.0.0/0


# Criar o Cluster EKS

ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

echo "Role ARN do Lab : $ROLE_ARN"
LIST_SUBNETS_IDS=
LIST_SECURITYGROUP_IDS=

aws eks create-cluster --name eksfiap --role-arn $ROLE_ARN --resources-vpc-config subnetIds=$LIST_SUBNETS_IDS,securityGroupIds=$SECURITYGROUP_IDS
aws eks describe-cluster --name eksfiap


# Criar os Nodes

aws eks create-nodegroup --cluster-name <cluster-name> --nodegroup-name <node-group-name> --subnets <subnet-ids> --security-groups <security-group-ids> --instance-types <instance-types> --ami-type AL2_x86_64
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <node-group-name>


# Update Kubeconfig file

aws eks update-kubeconfig --region <region-name> --name <cluster-name>

kubectl cluster-info

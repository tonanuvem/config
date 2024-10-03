EKS_VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[].VpcId" --output text --filters 'Name=tag:Name,Values=*eksfiap')
echo "EKS_VPC_ID = $EKS_VPC_ID. Finalizando os recursos..."
echo ""
chmod +x delete_vpc.sh
./delete_vpc.sh --region us-east-1 --vpc-id $EKS_VPC_ID --non-interactive 
# https://github.com/lianghong/delete_vpc/blob/master/delete_vpc.sh

echo ""
echo ""
echo "Finalizando o restante do projeto"
echo ""

terraform destroy -auto-approve

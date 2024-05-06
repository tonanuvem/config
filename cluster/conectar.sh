#echo "Os IPs das máquinas do Cluster serão exibidos a seguir, aguardar."
echo ""
#aws ec2 describe-instances --query "Reservations[*].Instances[*].[PublicIpAddress, Tags[?Key=='Name'].Value|[0]]" --output text | grep -v None | grep cluster
#echo ""
#echo "Copie e cole um dos IPs exibidos acimas : " 
#read IP
terraform apply --auto-approve > /dev/null
echo "Em qual NODE você deseja conectar? Digitar: 1 ou 2 ou 3" 
read NODENUM
NODE="Node_${NODENUM}_ip_externo"
export IP=$(terraform output -raw $NODE)

echo "Conectando.. IP = $IP.."
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP

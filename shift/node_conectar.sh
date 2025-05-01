#echo "Os IPs das máquinas do Cluster serão exibidos a seguir, aguardar."
echo ""
#aws ec2 describe-instances --query "Reservations[*].Instances[*].[PublicIpAddress, Tags[?Key=='Name'].Value|[0]]" --output text | grep -v None | grep cluster
#echo ""
#echo "Copie e cole um dos IPs exibidos acimas : " 
#read IP

# Verifica se um parâmetro foi passado
if [ -n "$1" ]; then
  NODENUM="$1"
else
  # Caso não tenha sido passado, solicita ao usuário
  echo "Em qual NODE você deseja conectar? Digitar: 1 ou 2 ou 3"
  read NODENUM
fi

IP=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_'$NODENUM'/) ) { print $1} }')

echo "Conectando.. IP = $IP"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP

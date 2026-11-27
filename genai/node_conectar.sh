# Verifica se um parâmetro foi passado
if [ -n "$1" ]; then
  NODENUM="$1"
else
  QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
  echo "Em qual NODE você deseja conectar? Digitar de 1 a $(expr $QTD_NODES - 1)"
  read NODENUM
fi

IP=$(terraform output -json ip_externo | jq .[] | jq .[$NODENUM] | sed 's/"//g')
echo "Conectando.. IP = $IP"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP

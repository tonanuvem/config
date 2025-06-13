if [ -n "$1" ]; then
  NODENUM="$1"
else
  # Caso não tenha sido passado, solicita ao usuário
  echo "Em qual NODE você deseja conectar? Digitar: 1 ou 2"
  read NODENUM
fi

NODE=$(terraform output -json ip_externo | jq -r '.[$NODENUM]')

echo "Conectando.. IP = $NODE"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$NODE

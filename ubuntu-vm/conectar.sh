#echo "Em qual NODE você deseja conectar? Digitar ex: 0 ou 1 ou 2 (etc)" 
#read NODENUM

echo "Conectando ..." 
terraform apply --auto-approve > /dev/null

NODENUM=0

IP=$(terraform output -json ip_externo | jq .[] | jq .[$NODENUM] | sed 's/"//g')
#IP=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/ubuntuvm_'$NODENUM'/) ) { print $1} }')

echo "Conectando.. IP = $IP"
ssh ubuntu@${IP} -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem

echo "Em qual NODE você deseja conectar? Digitar ex: 1 ou 2 ou 3" 
read NODENUM
IP=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/ubuntuvm_'$NODENUM'/) ) { print $1} }')

echo "Conectando.. IP = $IP"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP

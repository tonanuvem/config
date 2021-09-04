# conectar

IP=$(terraform output ip_externo)

echo "Conectando.. IP = $IP.."
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP

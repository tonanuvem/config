MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
echo "Conectando.. IP = $MASTER"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER

MASTER=$(terraform output -json ip_externo | jq .[0] | jq .[] | sed 's/"//g')
echo "Conectando.. IP = $MASTER"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$MASTER

MASTER=$(terraform output -json ip_externo | jq -r '.[0]')
user=ubuntu
echo "Conectando.. IP = $MASTER"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$MASTER

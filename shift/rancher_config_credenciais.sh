#!/bin/bash
sudo docker run -d -p 80:80 -p 443:443 --restart=unless-stopped --privileged --name rancher-server rancher/rancher:latest

# https://gist.githubusercontent.com/superseb/c363247c879e96c982495daea1125276/raw/bd907d2a98b7ad48c8ae96aa8335d183f433dde6/rancher2customnodecmd.sh
echo "  Aguardando componentes do Rancher "
while ! curl -ks https://localhost/ping; do printf . && sleep 3; done

# Descobrir senha
TEMPSENHA=$(docker logs  rancher-server  2>&1 | grep -oP '(?<=Bootstrap Password: ).*')
printf "\n\n\tTEMPORARIA SENHA = $TEMPSENHA"
echo $TEMPSENHA > TEMPSENHA

# Login
curl -s 'https://127.0.0.1/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'${TEMPSENHA}'"}' --insecure | jq -r .token > LOGINTOKEN
cat LOGINTOKEN
LOGINTOKEN=$(cat LOGINTOKEN)
printf "\n\n\tLOGINTOKEN = $LOGINTOKEN"

# Create API key
curl -s 'https://127.0.0.1/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer ${LOGINTOKEN}" --data-binary '{"type":"token","description":"automation"}' --insecure | jq -r .token > APITOKEN
cat APITOKEN
APITOKEN=$(cat APITOKEN)
printf "\n\n\tAPITOKEN = $APITOKEN"

# Change password
echo "Alterando a senha para: fiapfiapfiap"
SENHA=fiapfiapfiap
curl -s 'https://127.0.0.1/v3/users?action=changepassword' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"'${TEMPSENHA}'","newPassword":"'${SENHA}'"}' --insecure

# Set server-url
HOST_IP=$(curl checkip.amazonaws.com)
RANCHER_SERVER="fiap.${HOST_IP}.nip.io"
echo "Configurando o endereço do Rancher: $RANCHER_SERVER"
curl -s 'https://127.0.0.1/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"'$RANCHER_SERVER'"}' --insecure

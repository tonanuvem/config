#!/bin/bash
sudo docker run -d -p 80:80 -p 443:443 --restart=unless-stopped --privileged --name rancher-server rancher/rancher:latest

# https://gist.githubusercontent.com/superseb/c363247c879e96c982495daea1125276/raw/bd907d2a98b7ad48c8ae96aa8335d183f433dde6/rancher2customnodecmd.sh
echo "  Aguardando componentes do Rancher "
while ! curl -ks https://localhost/ping; do printf . && sleep 3; done

# Descobrir senha
SENHA=$(docker logs  rancher-server  2>&1 | grep -oP '(?<=Bootstrap Password: ).*')
echo "TEMPORARIA SENHA = $SENHA"

# Login
curl -s 'https://127.0.0.1/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'${SENHA}'"}' --insecure | jq -r .token > LOGINTOKEN
cat LOGINTOKEN
LOGINTOKEN=$(cat LOGINTOKEN)
echo "LOGINTOKEN = $LOGINTOKEN"

# Create API key
curl -s 'https://127.0.0.1/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer ${LOGINTOKEN}" --data-binary '{"type":"token","description":"automation"}' --insecure | jq -r .token > APITOKEN
cat APITOKEN
APITOKEN=$(cat APITOKEN)
echo "APITOKEN = $APITOKEN"

# Change password
echo "Alterando a senha para fiap"
curl -s 'https://127.0.0.1/v3/users?action=changepassword' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"'${SENHA}'","newPassword":"fiap"}' --insecure
SENHA=fiap

# Set server-url
HOST_IP=$(curl checkip.amazonaws.com)
RANCHER_SERVER="fiap.${HOST_IP}.nip.io"
echo "Configurando o endereço do Rancher: $RANCHER_SERVER"
curl -s 'https://127.0.0.1/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"'$RANCHER_SERVER'"}' --insecure

# Create cluster
echo "Criando o Cluster"
curl -s 'https://127.0.0.1/v3/cluster' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"dockerRootDir":"/var/lib/docker","enableNetworkPolicy":false,"type":"cluster","rancherKubernetesEngineConfig":{"addonJobTimeout":30,"ignoreDockerVersion":true,"sshAgentAuth":false,"type":"rancherKubernetesEngineConfig","authentication":{"type":"authnConfig","strategy":"x509"},"network":{"type":"networkConfig","plugin":"canal"},"ingress":{"type":"ingressConfig","provider":"nginx"},"monitoring":{"type":"monitoringConfig","provider":"metrics-server"},"services":{"type":"rkeConfigServices","kubeApi":{"podSecurityPolicy":false,"type":"kubeAPIService"},"etcd":{"snapshot":false,"type":"etcdService","extraArgs":{"heartbeat-interval":500,"election-timeout":5000}}}},"name":"fiap"}' --insecure | jq -r .id > CLUSTERID
cat CLUSTERID
CLUSTERID=$(cat CLUSTERID)
echo "CLUSTERID = $CLUSTERID"

# Create token
echo "Criando o token"
curl -s 'https://127.0.0.1/v3/clusterregistrationtoken' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure

# Set role flags
ROLEFLAGS="--etcd --controlplane --worker"

# Generate nodecommand
AGENTCMD=$(curl -s 'https://127.0.0.1/v3/clusterregistrationtoken?id="'$CLUSTERID'"' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --insecure | jq -r '.data[].nodeCommand' | head -1)
echo "AGENTCMD = $AGENTCMD"

printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"

# Concat commands
DOCKERRUNCMD="$AGENTCMD $ROLEFLAGS"
echo "$DOCKERRUNCMD" > DOCKERRUNCMD

# Echo command
cat DOCKERRUNCMD


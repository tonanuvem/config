#!/bin/bash
docker run -d -p 80:80 -p 443:443 --restart=unless-stopped --privileged --name rancher-server rancher/rancher:latest

while ! curl -ks https://localhost/ping; do printf . && sleep 3; done

# Descobrir senha
SENHA=$(docker logs  rancher-server  2>&1 | grep -oP '(?<=Bootstrap Password: ).*')

# Login
LOGINRESPONSE=$(curl -s 'https://127.0.0.1/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'${SENHA}'"}' --insecure) 
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
echo "LOGINTOKEN = $LOGINTOKEN"

# Change password
curl -s 'https://127.0.0.1/v3/users?action=changepassword' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"admin","newPassword":"fiap"}' --insecure

# Create API key
APIRESPONSE=$(curl -s 'https://127.0.0.1/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer "'$LOGINTOKEN'"" --data-binary '{"type":"token","description":"automation"}' --insecure)
# Extract and store token
APITOKEN=$(echo $APIRESPONSE | jq -r .token)
echo "APIRESPONSE = $APIRESPONSE"

# Set server-url
HOST_IP=$(curl checkip.amazonaws.com)
RANCHER_SERVER="fiap.${HOST_IP}.nip.io"
echo "Configurando o endereço do Rancher: $RANCHER_SERVER"
curl -s 'https://127.0.0.1/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"'$RANCHER_SERVER'"}' --insecure > /dev/null

# Create cluster
CLUSTERRESPONSE=$(curl -s 'https://127.0.0.1/v3/cluster' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"dockerRootDir":"/var/lib/docker","enableNetworkPolicy":false,"type":"cluster","rancherKubernetesEngineConfig":{"addonJobTimeout":30,"ignoreDockerVersion":true,"sshAgentAuth":false,"type":"rancherKubernetesEngineConfig","authentication":{"type":"authnConfig","strategy":"x509"},"network":{"type":"networkConfig","plugin":"canal"},"ingress":{"type":"ingressConfig","provider":"nginx"},"monitoring":{"type":"monitoringConfig","provider":"metrics-server"},"services":{"type":"rkeConfigServices","kubeApi":{"podSecurityPolicy":false,"type":"kubeAPIService"},"etcd":{"snapshot":false,"type":"etcdService","extraArgs":{"heartbeat-interval":500,"election-timeout":5000}}}},"name":"yournewcluster"}' --insecure)
# Extract clusterid to use for generating the docker run command
CLUSTERID=$(echo $CLUSTERRESPONSE | jq -r .id)

# Create token
curl -s 'https://127.0.0.1/v3/clusterregistrationtoken' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure > /dev/null

# Set role flags
ROLEFLAGS="--etcd --controlplane --worker"

# Generate nodecommand
AGENTCMD=$(curl -s 'https://127.0.0.1/v3/clusterregistrationtoken?id="'$CLUSTERID'"' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --insecure | jq -r '.data[].nodeCommand' | head -1)

# Concat commands
DOCKERRUNCMD="$AGENTCMD $ROLEFLAGS"

# Echo command
echo $DOCKERRUNCMD
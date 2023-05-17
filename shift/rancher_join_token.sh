# Get nodecommand
CLUSTERID=$(cat CLUSTERID)
APITOKEN=$(cat APITOKEN)
echo "  Aguardando Token para o Cluster "
while [ "$(curl -s 'https://127.0.0.1/v3/clusterregistrationtoken/' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --insecure | grep nodeCommand | wc -l)" != "1" ]; do
  printf "."
  sleep 1
done
sleep 5
AGENTCMD=$(curl -s 'https://127.0.0.1/v3/clusterregistrationtoken?id="'$CLUSTERID'"' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --insecure | jq -r '.data[].nodeCommand' | head -1)
#printf "\n\n\tAGENTCMD = $AGENTCMD"
echo $AGENTCMD > AGENTCMD

printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"

# Concat commands
# Set role flags
AGENTCMD=$(cat AGENTCMD)
ROLEFLAGS="--etcd --controlplane --worker"
DOCKERRUNCMD="$AGENTCMD $ROLEFLAGS"
echo "$DOCKERRUNCMD" > DOCKERRUNCMD

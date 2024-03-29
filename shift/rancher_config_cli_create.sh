# https://rancher.com/docs/rancher/v2.x/en/quick-start-guide/deployment/quickstart-manual-setup/#4-create-the-cluster
# https://rancher.com/docs/rancher/v2.x/en/cli/
# https://github.com/rancher/cli/releases

# wget https://github.com/rancher/cli/releases/download/v2.4.12/rancher-linux-amd64-v2.4.12.tar.gz
curl -s https://github.com/rancher/cli/releases/download/v2.4.12/rancher-linux-amd64-v2.4.12.tar.gz -o rancher-linux-amd64-v2.4.12.tar.gz

tar -zxvf rancher-linux-amd64-v2.4.12.tar.gz
sudo mv rancher-v2.4.12/rancher /usr/local/bin/

APITOKEN=$(cat APITOKEN)
CLUSTERID=$(cat APITOKEN)

rancher login https://localhost -t $APITOKEN --skip-verify
rancher clusters create fiap
rancher clusters add-node --etcd --controlplane --worker fiap > JOINTOKEN

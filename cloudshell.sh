#!/bin/bash

echo "\n\n Ajustando as pastas do CloudShell e a permissão do arquivo labsuser.pem"

## Retrieve AWS credentials from AWS CloudShell : aws-cloud-shell-get-aws-credentials.sh
# https://gist.github.com/dclark/b014ac10540ca2d6911c643b8956fc50

# shellcheck disable=SC2001
HOST=$(echo "$AWS_CONTAINER_CREDENTIALS_FULL_URI" | sed 's|/latest.*||')
TOKEN=$(curl -s -X PUT "$HOST"/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
OUTPUT=$(curl -s "$HOST/latest/meta-data/container/security-credentials" -H "X-aws-ec2-metadata-token: $TOKEN")
echo "export AWS_ACCESS_KEY_ID=$(echo "$OUTPUT" | jq -r '.AccessKeyId')"
echo "export AWS_SECRET_ACCESS_KEY=$(echo "$OUTPUT" | jq -r '.SecretAccessKey')"
echo "export AWS_SESSION_TOKEN=$(echo "$OUTPUT" | jq -r '.Token')"

printf "\n\tVERIFICANDO ARQUIVO DE CHAVE labsuser.pem :\n\n"
if [ $(ls ~ | grep config | wc -l) = "1" ]
then
  mkdir ~/environment/
  mv  ~/config ~/environment/config
else
  echo "\t\Pasta CONFIG não encontrada, você deve fazer rodar o comando git clone na pasta raiz\n\n"
  exit
fi

if [ $(ls ~ | grep labsuser.pem | wc -l) = "1" ]
then
  printf "\t\tARQUIVO labsuser.pem OK!\n\n"
  mv  ~/labsuser.pem ~/environment/labsuser.pem
  chmod 400 ~/environment/labsuser.pem
  sh ~/environment/config/preparar.sh
else
  echo "\t\tArquivo labsuser.pem não encontrado, você deve fazer o upload do arquivo para o CloudShell\n\n"
  exit
fi


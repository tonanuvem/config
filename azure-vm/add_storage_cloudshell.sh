# Variáveis (altere conforme necessário)
RESOURCE_GROUP="cloud-shell-rg"
LOCATION="eastus"
STORAGE_ACCOUNT="cloudshell$RANDOM"
FILE_SHARE_NAME="cloudshell"

# Cria o grupo de recursos (caso não exista)
az group create --name $RESOURCE_GROUP --location $LOCATION

# Cria a conta de armazenamento com suporte a file share
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

# Obtém a chave da conta
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' \
  --output tsv)

# Cria o file share
az storage share create \
  --name $FILE_SHARE_NAME \
  --account-name $STORAGE_ACCOUNT \
  --account-key $ACCOUNT_KEY

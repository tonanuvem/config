#!/bin/bash

# Variáveis
RESOURCE_GROUP="fiapvm"
VM_NAME="fiaplab-vm"

# Verifica o estado atual da VM
VM_STATE=$(az vm get-instance-view \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].code" \
  --output tsv)

echo ""
echo "Estado atual da VM '$VM_NAME': $VM_STATE"
echo ""
if [[ "$VM_STATE" == "PowerState/deallocated" || "$VM_STATE" == "PowerState/stopped" ]]; then
    echo "A VM está desligada. Vamos INICIAR!"
    echo ""
    az vm start --resource-group $RESOURCE_GROUP --name $VM_NAME
    echo "VM iniciada."
    echo ""
    echo "Atualizando as informações da VM:"
    terraform apply --auto-approve > /dev/null
    export IP=$(terraform output -raw ip_externo)
    echo "   IP = $IP.."
    echo ""
else
    echo "Estado não suportado: $VM_STATE"
fi
sh url.sh
echo ""

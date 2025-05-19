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
if [[ "$VM_STATE" == "PowerState/running" ]]; then
    echo "A VM está ligada. Vamos SUSPENDER!"
    echo ""
    az vm deallocate --resource-group $RESOURCE_GROUP --name $VM_NAME
    echo "VM parada e recursos desalocados."
    echo "Estamos economizando seus créditos."
    echo ""
else
    echo "Estado não suportado: $VM_STATE"
fi
echo ""

#!/bin/bash

# Variáveis
RESOURCE_GROUP="fiapvm"
VM_NAME="minha-vm"

# Verifica o estado atual da VM
VM_STATE=$(az vm get-instance-view \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].code" \
  --output tsv)

echo "Estado atual da VM '$VM_NAME': $VM_STATE"

if [[ "$VM_STATE" == "PowerState/running" ]]; then
    read -p "A VM está ligada. Deseja PARAR (deallocate)? (s/n): " OP
    if [[ "$OP" == "s" ]]; then
        az vm deallocate --resource-group $RESOURCE_GROUP --name $VM_NAME
        echo "VM parada e recursos desalocados."
        echo "Estamos economizando seus créditos."
        echo ""
    else
        echo "Ação cancelada."
    fi
elif [[ "$VM_STATE" == "PowerState/deallocated" || "$VM_STATE" == "PowerState/stopped" ]]; then
    read -p "A VM está desligada. Deseja INICIAR? (s/n): " OP
    if [[ "$OP" == "s" ]]; then
        az vm start --resource-group $RESOURCE_GROUP --name $VM_NAME
        echo "VM iniciada."
        echo ""
        echo "Atualizando as informações da VM:"
        terraform apply --auto-approve > /dev/null
        export IP=$(terraform output -raw $NODE)
        echo "   IP = $IP.."
        echo ""
    else
        echo "Ação cancelada."
    fi
else
    echo "Estado desconhecido ou não suportado: $VM_STATE"
fi

terraform init; terraform plan; terraform apply -auto-approve
echo ""
echo " Iniciando configurações: "
sh ajustar.sh
#sh config-node1.sh
#sh config-node2.sh
#sh config-node3.sh
echo ""
echo " Cluster iniciado e configurado"

echo ""

terraform init; terraform plan -out main.tfplan; terraform apply -auto-approve main.tfplan 

echo ""
echo "   Aguardando configurações: "

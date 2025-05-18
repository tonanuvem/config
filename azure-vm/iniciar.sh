echo ""

terraform init; terraform plan -out main.tfplan; terraform apply -auto-approve main.tfplan 

echo ""
echo "   Aguardando configurações: "
sleep 10
echo "   Salvando a chave privada em arquivo (~/environment/labsuser.pem): "
terraform output -raw private_key_pem > ~/environment/labsuser.pem
chmod 600 ~/environment/labsuser.pem
echo "   Verificando conexão com o ambiente: "
export IP=$(terraform output -raw ip_externo)
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$IP "echo CONECTADO" | grep CONECTADO | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "

sh ajustar.sh

echo "   Configuração OK."
echo ""
echo "   OBS: Caso alguma das tarefas anteriores tenha obtido FAILED, executar: sh ajustar.sh"
echo ""
echo "   ACESSAR: http://$IP:8099              ( senha = fiap )"
echo ""

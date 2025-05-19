echo "   Verificando Configuração."
export IP=$(terraform output -raw ip_externo)
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$IP "echo CONECTADO" | grep CONECTADO | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Configuração OK."
echo ""
echo "   ACESSAR: http://$IP:8099              ( senha = fiap )"
echo ""

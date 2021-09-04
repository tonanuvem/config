terraform init; terraform plan; terraform apply -auto-approve
echo ""
echo "   Aguardando configurações: "
sleep 10
export IP=$(terraform output ip_externo)
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO" | grep CONECTADO | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
sh ajustar.sh
echo "   Configuração OK."

#ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP 'bash -s' < ../preparar.sh
#ssh  -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "while [ \$(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done"
#ssh -i "~/environment/labsuser.pem" ubuntu@$IP "while [ $(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done"
#ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "while [ \$(dpkg -l | grep kubeadm | wc -l) != '1' ]; do { printf .; sleep 1; } done"

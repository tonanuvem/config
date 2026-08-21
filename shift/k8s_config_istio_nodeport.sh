#!/bin/sh

# conectar no master e configurar

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')

# Criando arquivos vazios para receber os comandos
> istio.sh

echo "IPs configurados :"
echo "MASTER = $MASTER"

# CONFIGURANDO O MASTER:

echo ""
echo "Iniciando a instalação do Istio:"
echo ""
echo "curl -L https://istio.io/downloadIstio | sh -" >> istio.sh
echo "cd istio-* && export PATH=$PWD/bin:$PATH" >> istio.sh
echo "istioctl install --set profile=demo --skip-confirmation" >> istio.sh
echo ""
echo "Configurando o Istio:"
echo ""
echo "kubectl create -f samples/addons" >> istio.sh
echo "kubectl label namespace default istio-injection=enabled" >> istio.sh
echo "kubectl patch svc kiali -n istio-system -p '{"spec": {"type": "NodePort"}}' && kubectl get svc kiali -n istio-system" >> istio.sh
echo ""
echo "Verificando a porta do Kiali a instalação do Istio:" >> istio.sh
echo "kubectl get svc kiali -n istio-system| grep 20001" >> istio.sh


### CONFIGURANDO O MASTER via SSH
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < istio.sh


### CONFIGURANDO O DAHBOARD 
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < k8s_dashboard_token.sh

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'kubectl get nodes'
printf "\n\n"

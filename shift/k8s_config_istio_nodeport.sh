#!/bin/sh

# IP do MASTER
MASTER=$(terraform output -json ip_externo | jq -r '.[0][0]')

# Criando arquivo de comandos
> istio.sh

echo "IPs configurados:"
echo "MASTER = $MASTER"

cat > istio.sh <<'EOF'
#!/bin/bash

set -e

echo ""
echo "========================================"
echo "        INSTALANDO ISTIO"
echo "========================================"
echo ""

curl -L https://istio.io/downloadIstio | sh -

cd istio-*

export PATH=$PWD/bin:$PATH

echo ""
echo "Instalando Istio com profile demo..."
echo ""

istioctl install --set profile=demo --skip-confirmation

echo ""
echo "========================================"
echo "        CONFIGURANDO ISTIO"
echo "========================================"
echo ""

kubectl create -f samples/addons

kubectl label namespace default istio-injection=enabled --overwrite

kubectl patch svc kiali -n istio-system \
  -p '{"spec":{"type":"NodePort"}}'

echo ""
echo "Serviço Kiali:"
kubectl get svc kiali -n istio-system

echo ""
echo "Porta do Kiali:"
kubectl get svc kiali -n istio-system | grep 20001 || true

echo ""
echo "========================================"
echo "        ACESSO AO KIALI"
echo "========================================"
echo ""

KIALI_PORT=$(kubectl get svc kiali -n istio-system \
  -o jsonpath='{.spec.ports[?(@.port==20001)].nodePort}')

echo ""
echo "Acessar Kiali:"
echo "http://$KIALI_IP:$KIALI_PORT"
echo ""
EOF

chmod +x istio.sh

echo ""
echo "Configurando o MASTER via SSH..."
echo ""

ssh -oStrictHostKeyChecking=no \
    -i ~/environment/labsuser.pem \
    ec2-user@$MASTER 'bash -s' < istio.sh

echo ""
echo "Configurando o Dashboard..."
echo ""

ssh -oStrictHostKeyChecking=no \
    -i ~/environment/labsuser.pem \
    ec2-user@$MASTER 'bash -s' < k8s_dashboard_token.sh

printf "\n\n"
echo "========================================"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
echo "========================================"
echo ""

ssh -oStrictHostKeyChecking=no \
    -i ~/environment/labsuser.pem \
    ec2-user@$MASTER \
    'kubectl get nodes'

printf "\n\n"

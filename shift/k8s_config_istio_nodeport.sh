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

#curl -L https://istio.io/downloadIstio | sh -
export ISTIO_VERSION=$(curl -sSL https://api.github.com/repos/istio/istio/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -

#cd istio-*
cd istio-$ISTIO_VERSION

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

#kubectl create -f samples/addons
kubectl apply -f samples/addons

kubectl label namespace default istio-injection=enabled --overwrite

echo ""
echo "========================================"
echo "     INSTALANDO BOOKINFO (DEMO)"
echo "========================================"
echo ""

kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml

kubectl patch svc kiali -n istio-system \
  -p '{"spec":{"type":"NodePort"}}'

kubectl patch svc grafana -n istio-system \
  -p '{"spec":{"type":"NodePort"}}'

echo ""
echo "Serviço Kiali:"
kubectl get svc kiali -n istio-system

echo ""
echo "Porta do Kiali:"
kubectl get svc kiali -n istio-system | grep 20001 || true

echo ""
echo "Aguardando pods da aplicação Bookinfo iniciarem..."
kubectl rollout status deployment/productpage-v1 --timeout=120s || true

echo ""
echo "========================================"
echo "   ACESSO ÀS FERRAMENTAS E DEMO ISTIO"
echo "========================================"
echo ""

KIALI_IP=$(curl -s checkip.amazonaws.com)
KIALI_PORT=$(kubectl get svc kiali -n istio-system \
  -o jsonpath='{.spec.ports[?(@.port==20001)].nodePort}')
INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GRAFANA_PORT=$(kubectl get svc grafana -n istio-system \
  -o jsonpath='{.spec.ports[0].nodePort}')

# Gera tráfego inicial via Gateway para já popular o grafo no Kiali sem 'unknown'
for i in $(seq 1 10); do
  curl -s -o /dev/null "http://localhost:$INGRESS_PORT/productpage" || true
done

echo ""
echo "1) Acessar Kiali:"
echo "http://$KIALI_IP:$KIALI_PORT"
echo ""
echo "2) Acessar Productpage (Bookinfo via Istio Ingress Gateway):"
echo "http://$KIALI_IP:$INGRESS_PORT/productpage"
echo ""
echo "3) Acessar Grafana:"
echo "http://$KIALI_IP:$GRAFANA_PORT"
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

printf "\n\n"

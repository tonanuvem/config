#!/bin/bash
export COLOR_RESET='\e[0m'
export COLOR_LIGHT_GREEN='\e[0;49;32m' 

export INGRESS_HOST=$(curl -s checkip.amazonaws.com)

wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.5.0/aio/deploy/recommended.yaml

# Ajustar para acessar de maneira insegura (somente para LAB):
# Substituir a linha:
#            - --auto-generate-certificates
#RETIRAR=$(cat recommended.yaml | grep auto-generate-certificates)
# pelas linhas abaixo:
#INSERIR="$(cat <<-EOF
#            - --enable-skip-login
#            - --disable-settings-authorizer
#            - --enable-insecure-login
#            - --insecure-bind-address=0.0.0.0
#EOF
#)"
#echo "$RETIRAR"
#echo "$INSERIR"

# Replaces all occurrences of the regular expression $RETIRAR in the file with the contents of $INSERIR:
#sed -i 's|            - --auto-generate-certificates|            - --enable-skip-login\n            - --disable-settings-authorizer\n            - --enable-insecure-login\n            - --insecure-bind-address=0.0.0.0\n|' recommended.yaml
sed -i 's|            - --auto-generate-certificates|            - --auto-generate-certificates\n            - --enable-skip-login\n|' recommended.yaml

kubectl apply -f recommended.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: kubernetes-dashboard-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "kubernetes-dashboard"
  labels:
    k8s-app: kubernetes-dashboard
EOF

kubectl apply -f https://raw.githubusercontent.com/tonanuvem/k8s-exemplos/master/dashboard_permission.yml

kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec": {"type": "NodePort"}}'
kubectl get svc kubernetes-dashboard -n kubernetes-dashboard
export INGRESS_PORT=$(kubectl -n kubernetes-dashboard get service kubernetes-dashboard -o jsonpath='{.spec.ports[?()].nodePort}')
echo ""
echo "Acessar K8S Dashboard: https://$INGRESS_HOST:$INGRESS_PORT"

echo ""
echo "Kubernetes dashboard access token."
echo ""

# kubectl describe -n kubernetes-dashboard secret kubernetes-dashboard-token
ENCODED_TOKEN=$(kubectl get secret kubernetes-dashboard-token -n kubernetes-dashboard -o=jsonpath='{.data.token}')

#SECRET_RESOURCE=$(kubectl get secrets -n kubernetes-dashboard -o name | grep kubernetes-dashboard-token)
#ENCODED_TOKEN=$(kubectl get $SECRET_RESOURCE -n kubernetes-dashboard -o=jsonpath='{.data.token}')
export TOKEN=$(echo $ENCODED_TOKEN | base64 --decode)
echo ""
echo "--- Copy and paste this token for dashboard access ---"
echo -e $COLOR_LIGHT_GREEN
echo -e $TOKEN
echo -e $COLOR_RESET

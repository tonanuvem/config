# metrics-server: destrava "kubectl top", que e a metrica de infraestrutura
# mais barata do plano (RAM por no e CPU por no, item 4 dos KPIs).
#
# A pegadinha: em cluster kubeadm o kubelet usa certificado autoassinado que
# nao e da CA do cluster. Sem --kubelet-insecure-tls o deployment sobe, mas o
# APIService fica Available=False com "connection refused" e o kubectl top
# nunca funciona.
#
# O que ele NAO cobre, e que o item 4 vai precisar de Prometheus para ter:
#   - historico (aqui so ha o instantaneo)
#   - trafego de rede entre nos  <- a metrica critica deste projeto
#   - metrica por processo/thread da engine

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.1/components.yaml

kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

echo ""
echo "Aguardando a primeira coleta..."
for i in 1 2 3 4 5 6; do
  if kubectl top nodes 2>/dev/null | grep -q NAME; then kubectl top nodes; break; fi
  printf "."; sleep 15
done

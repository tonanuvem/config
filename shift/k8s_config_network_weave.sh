# Configurar a rede (pod network) no Master:

kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
#kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Executar Ferramenta Gráfica de administração da Weave Works:

kubectl apply -f https://github.com/weaveworks/scope/releases/download/v1.13.2/k8s-scope.yaml
#kubectl apply -f "https://cloud.weave.works/k8s/scope.yaml?k8s-service-type=NodePort&k8s-version=$(kubectl version | base64 | tr -d '\n')"
#kubectl patch svc weave-scope-app -n weave -p '{"spec": {"type": "NodePort"}}'  

kubectl patch svc weave-scope-app -n weave -p \
  '{"spec": { "type": "NodePort", "ports": [ { "nodePort": 32040, "port": 80, "protocol": "TCP", "targetPort": 4040 } ] } }'
  
kubectl get svc -n weave

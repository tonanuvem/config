# Rede do cluster (weave).
#
# Duas diferencas em relacao ao shift/k8s_config_network_weave.sh:
#
# 1. MTU. O weave sobe com MTU 1376 enquanto o host tem 9001 (jumbo frames na
#    enX0). Em inferencia distribuida a rede entre nos e o gargalo -- foram
#    medidos 285 Mbit/s pod-a-pod com RTT de 1,10 ms -- e MTU baixo e taxa de
#    encapsulamento pura. WEAVE_MTU sobe isso. Medir antes e depois: se a
#    banda nao melhorar, o teto e da instancia, nao do CNI.
#
# 2. Sem weave-scope. A GUI consome de 14 a 48 milicores e ~46 MiB em CADA no.
#    Em no de 2 vCPU isso e ate 2,4% de um core competindo com o benchmark.

kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# MTU: 9001 do host menos o overhead de encapsulamento do weave.
kubectl -n kube-system set env daemonset/weave-net --containers=weave WEAVE_MTU=8916

kubectl -n kube-system rollout status daemonset/weave-net --timeout=180s

echo ""
echo "MTU efetivo nos nos (esperado ~8916, nao 1376):"
kubectl get nodes -o name | sed 's|node/||' | head -2

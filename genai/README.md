# genai — cluster para inferência distribuída de LLM em CPU

Infraestrutura do projeto descrito em
[`k8s-exemplos/llm/DESCRICAO.md`](https://github.com/tonanuvem/k8s-exemplos/blob/master/llm/DESCRICAO.md):
unir a RAM de vários nós para rodar modelos que não cabem em uma máquina só.

Mesmos moldes do `shift/` — mesmo fluxo, mesmos playbooks de base — mas com os
parâmetros derivados de medições no lab, não de hábito.

## Fluxo

```bash
sh iniciar.sh              # terraform apply + ansible (chama ajustar.sh)
sh k8s_create_cluster.sh   # kubeadm init/join, weave, local-path, metrics-server
sh conectar.sh             # ssh no master
sh node_conectar.sh 2      # ssh no worker 2
sh destruir.sh             # terraform destroy
```

## O que muda em relação ao `shift/`, e por quê

| | `shift/` | `genai/` | Motivo |
| :--- | :--- | :--- | :--- |
| Tipo | `t2.large` | **`r5.large`** | t2 é burstável: ~40 min de CPU plena e cai para 60% de baseline, o que destrói a reprodutibilidade. r5.large tem **16 GiB** — o dobro de RAM pelo mesmo nº de vCPU, e RAM é o gargalo aqui. |
| Nós | 4 (1+3) | **6 (1+5)** | 4 workers viram ranks (4 = 2², exigência do `distributed-llama`) e 1 hospeda n8n/LangGraph/Prometheus, fora dos ranks para não contaminar a medição. |
| Disco | 50 GB raiz + 50 GB **não montado** | 40 GB raiz + **/models** | O `xvdb` do shift nunca é formatado nem montado: 50 GB ociosos por nó. Aqui ele vira `/models`, grande (80 GB) só no nó 0, que é onde o arquivo do modelo vive. |
| IAM | nenhum | **`LabInstanceProfile`** | Dá acesso a S3 para cachear os GGUF entre sessões, e credenciais que se renovam sozinhas — as copiadas à mão expiram no meio do trabalho. |
| `user_data` | `../preparar.sh` | nenhum | Aquele script configura a VM do lab, não os nós: só dá `exit` no cloud-init. Some junto a última referência ao provider `hashicorp/template`, arquivado. |
| ICMP | fechado | **aberto no VPC** | Sem ele não dá para usar `ping` entre nós — justamente o diagnóstico da rede, que é o gargalo do projeto. |
| MTU do weave | 1376 (padrão) | **8916** | O host tem 9001 (jumbo frames). MTU baixo é taxa de encapsulamento pura num workload limitado por rede. |
| weave-scope | instalado | **removido** | A GUI consome 14–48 milicores e ~46 MiB em **cada** nó. Em nó de 2 vCPU é até 2,4% de um core competindo com o benchmark. |
| metrics-server | ausente | **instalado** | Destrava `kubectl top`, que é o KPI de infraestrutura mais barato do plano. |
| Playbook de storage | — | `ansible_genai_storage.yml` | Monta `/models` e ajusta o TCP. |

## Ansible: o que foi reaproveitado e o que é novo

Os cinco playbooks de base entram **sem nenhuma mudança**:

| Playbook | Papel |
| :--- | :--- |
| `ansible_hostname.yml` | nomes dos nós |
| `ansible_hosts.yml` | `/etc/hosts` |
| `ansible_utils.yml` | utilitários, repo do k8s 1.37 |
| `ansible_docker.yml` | Docker + plugins compose e buildx |
| `ansible_k8s.yml` | kubelet, kubeadm, containerd com `SystemdCgroup` |

**Um playbook novo**, `ansible/ansible_genai_storage.yml`, para as duas coisas
que nenhum deles faz: montar `/models` e afrouxar o TCP para tráfego em
rajadas. Ele detecta o dispositivo em vez de chutar, porque o nome muda com a
família — `/dev/xvdb` em Xen (t2), `/dev/nvme1n1` em Nitro (r5, m6i, c5n).

O `k8s_storage_helm_wordpress.yml`, que o `shift/ajustar.sh` chama, **não entra**:
é do lab de volumes e não tem relação com inferência.

## Limites do ambiente que moldaram estas escolhas

Validados por `dry-run` na conta; detalhes em
[`k8s-exemplos/llm/AWSACADEMY-RESTRICOES.md`](https://github.com/tonanuvem/k8s-exemplos/blob/master/llm/AWSACADEMY-RESTRICOES.md).

- Teto de instância é **`.large`**; todo `xlarge` recebe *explicit deny*, e
  passar do teto não dá erro no launch — a instância é terminada depois.
- **9 instâncias** na conta inteira e **32 vCPU**. Com `.large` = 2 vCPU, o
  limite de 9 aperta primeiro. A VM do code-server já ocupa 1.
- **Todo tipo permitido tem 2 vCPU.** Capacidade de CPU só cresce por nº de nós.
- EBS: máximo 100 GB por volume, e **EBS de instância parada continua faturando**.
- O lab **não é efêmero**: instâncias são paradas e reiniciadas, e o EBS
  sobrevive. Quem apaga os modelos é o `destruir.sh`.

## Ainda em aberto

- O nó de GPU (`g6f.large`, 1/8 de L4) **cabe nesta subnet**, porque a AZ está
  fixada em `us-east-1a` — uma das quatro que ofertam todos os tipos do plano,
  a GPU inclusive (`1f`, que o shift pegou por sorte, não oferta). Ainda assim
  a recomendação é rodá-lo **fora do k8s**, via SSH com a DLAMI
  `ami-08cd9f6cf45ce3c86`: é baseline de nó único, e assim evita device plugin.
- Se o MTU de 8916 não melhorar os 285 Mbit/s medidos, o teto é da instância e
  o caminho é `c5n.large` (até 25 Gbps).

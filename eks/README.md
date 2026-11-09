# Lab EKS - cluster Kubernetes gerenciado na AWS

Cria um cluster EKS (`eksfiap`) com 2 nos workers, numa VPC propria, usando
Terraform. Pensado para o AWS Academy / Learner Lab, onde a role `LabRole` e o
key pair `vockey` ja existem.

## Fluxo do lab

### Instalacao limpa (clone novo)

```bash
git clone https://github.com/tonanuvem/config.git && cd config/eks
```

```bash
sh config_credenciais.sh
```

```bash
sh iniciar.sh
```

```bash
sh conectar.sh
```

E, ao terminar o lab:

```bash
sh destruir.sh
```

### Reaproveitando um clone que ja existe

Nesse caso, e **so nesse caso**, comece atualizando o repositorio:

```bash
sh atualizar.sh
```

Depois siga a partir do `sh config_credenciais.sh`. Em clone novo o
`atualizar.sh` nao tem o que fazer: ele existe apenas para resgatar clones em
que os scripts antigos modificaram arquivos versionados.

| Passo | O que faz | Tempo |
|---|---|---|
| `sh atualizar.sh` | so em clone reaproveitado: `git pull` preservando as credenciais | segundos |
| `sh config_credenciais.sh` | le as credenciais coladas e grava em `files/credentials` | segundos |
| `sh iniciar.sh` | verificacoes previas + `terraform apply` | **12 a 15 min** |
| `sh conectar.sh` | abre um shell com `kubectl` apontado para o cluster | segundos |
| `sh destruir.sh` | remove cluster, workers e VPC | 8 a 12 min |

### Transicao: a primeira atualizacao de um clone antigo

Um clone feito **antes** destas mudancas ainda nao tem o `atualizar.sh`, e o
`git pull` nele falha porque os scripts antigos modificaram `main.tf` e
`files/credentials`. Rode **uma vez**, dentro de `config/eks`:

```bash
git checkout -- main.tf files/credentials && git pull
```

Perder o `files/credentials` nesse momento nao e problema: o passo seguinte do
lab (`sh config_credenciais.sh`) grava as credenciais de novo. A partir dai,
use `sh atualizar.sh` e o problema nao volta.

> `sh atualizar.sh` substitui o `git pull` direto. Os scripts antigos escreviam
> dentro de arquivos versionados (`main.tf` e `files/credentials`), o que fazia
> o `git pull` falhar com *"Your local changes would be overwritten by merge"*
> na segunda vez que o lab era executado. Se preferir, `git pull` continua
> funcionando - o `atualizar.sh` so resolve esse caso.

### De onde rodar

Funciona no AWS CloudShell, no Cloud9, em uma VM Linux ou na propria maquina.
Precisa de:

- `aws` (AWS CLI v2) e `terraform` para criar o ambiente
  (`sh ../terraform.sh` instala o terraform);
- para conectar, **ou** `aws` + `kubectl` instalados, **ou** Docker.
  `sh conectar.sh` escolhe sozinho (`MODO=auto`).

## O que e criado

- VPC `10.5.0.0/16` com DNS habilitado, 2 subnets publicas (uma por AZ),
  Internet Gateway e rota default;
- security group do control plane;
- cluster EKS `eksfiap`, com o criador ja mapeado como administrador;
- addon `aws-ebs-csi-driver`, necessario para qualquer PVC de disco;
- managed node group `demo`: 3 x `t3.large` (min 2, max 4), AMI Amazon
  Linux 2023, disco de 20 GiB.

Custo aproximado em `us-east-1`: ~US$ 0,10/h do control plane + ~US$ 0,25/h dos
3 nos `t3.large` (com 2 nos, ~US$ 0,17/h). Com `node_capacity_type = "SPOT"` os nos custam cerca de um
terco disso. **Rode `sh destruir.sh` ao terminar.**

### Por que t3.large e nao t3.medium

`t3.medium` tem 4 GiB, dos quais sobram ~3 GiB alocaveis depois do kubelet e
dos DaemonSets. Isso nao comporta stacks de observabilidade (Dynatrace, por
exemplo) e os pods ficam `Pending` com `Insufficient memory`. `t3.large` tem
8 GiB e o mesmo numero de vCPUs.

Prefira `t3.large` a `t2.large`: mesma CPU e memoria, geracao mais nova,
melhor baseline de burst e cerca de 10% mais barata.

### Por que 3 nos e nao 2

Depois de resolver a memoria, o gargalo virou **CPU**. Medido no lab com a
stack do Dynatrace, em 2 x `t3.large`:

| | CPU (requests) | Memoria (requests) |
|---|---|---|
| no 1 | 1490m de 1930m (77%) | 0,83 GiB de 6,9 (12%) |
| no 2 | 690m de 1930m (36%) | 1,38 GiB de 6,9 (20%) |
| **total, 2 nos** | **56%** | **16%** |
| **total, 3 nos** | **38%** | **11%** |

Sobravam 440m de CPU no no mais cheio - pouco para o controlador do driver de
EBS (2 replicas com anti-afinidade) e para as replicas do ActiveGate. O
terceiro no e tambem um terceiro dominio de falha: um StatefulSet de 3
replicas que exija anti-afinidade **nunca** agenda por completo em 2 nos.

Para conferir se alguma carga sua exige isso:

```bash
kubectl -n dynatrace get statefulset -o yaml | grep -A5 requiredDuringScheduling
```

Tres `t3.large` (~US$ 0,25/h) saem mais baratos e dao mais dominios de falha do
que dois `t3.xlarge` (~US$ 0,33/h). Num lab simples, sem observabilidade, 2 nos
bastam: `node_desired_size = 2`.

## Verificar o cluster

Dentro do shell aberto por `sh conectar.sh`:

```bash
kubectl get nodes
```

```bash
kubectl create deployment nginx --image=nginx --replicas=2
```

```bash
kubectl expose deployment nginx --type=LoadBalancer --port=80
```

```bash
kubectl get svc nginx -w
```

O `EXTERNAL-IP` leva 2 a 3 minutos para aparecer.

## Personalizar

Crie um `terraform.tfvars` (ja ignorado pelo git):

```hcl
cluster-name        = "meucluster"
node_desired_size   = 3
node_instance_types = ["t3.large"]
node_capacity_type  = "SPOT"        # reduz bastante o custo
cluster_ingress_cidrs = ["203.0.113.10/32"]
node_ssh_key_name   = ""            # sem acesso SSH aos nos
```

Ou use variaveis de ambiente nos scripts:

```bash
CLUSTER_NAME=meucluster AWS_REGION=us-east-2 sh iniciar.sh
```

Todas as variaveis estao documentadas em `variables.tf`.

Variaveis de ambiente aceitas pelos scripts: `CLUSTER_NAME`, `AWS_REGION`,
`SSH_KEY_NAME`, `CLUSTER_ROLE_NAME`, `NODE_ROLE_NAME`, `MODO`, `EKS_IMAGE`,
`EKS_BUILD`, `KUBECTL_VERSION`.
Quando definidas, elas sao repassadas ao terraform como `-var` e, portanto,
**tem precedencia sobre o `terraform.tfvars`**. No AWS CloudShell a variavel
`AWS_REGION` ja vem definida pelo ambiente - exatamente para que a AWS CLI e o
terraform usem sempre a mesma regiao.

### Escala automatica (Cluster Autoscaler)

`min_size` e `max_size` **nao ligam escala automatica**: eles so definem os
limites do Auto Scaling Group. Sem um controlador, um pod `Pending` por falta
de memoria continua `Pending`, mesmo com `max_size = 4`. Quem cria nos e o
Cluster Autoscaler, um Deployment dentro do cluster.

São dois passos. No `terraform.tfvars`:

```hcl
habilitar_autoscaler = true
```

```bash
sh iniciar.sh && sh autoscaler.sh
```

O primeiro passo marca o ASG com as tags de descoberta; o segundo instala o
Cluster Autoscaler na versao correspondente a do cluster. Para remover:

```bash
sh autoscaler.sh --remover
```

Duas observacoes:

- a role dos nos precisa de permissoes de `autoscaling:*` (a `LabRole` do AWS
  Academy costuma ter; o script avisa se os logs acusarem falta de permissao);
- com o autoscaler ativo, quem controla o `desired_size` e ele. Um
  `terraform apply` posterior devolve o valor de `node_desired_size`, e o
  autoscaler torna a subir os nos se houver pods `Pending`.

Sem o autoscaler, da para escalar na mao a qualquer momento:

```bash
aws eks update-nodegroup-config --cluster-name eksfiap --nodegroup-name demo \
    --scaling-config minSize=2,maxSize=4,desiredSize=4
```

### Opcoes dos scripts

```bash
sh iniciar.sh --check      # so roda as verificacoes previas
```

```bash
sh iniciar.sh --plan       # so mostra o que seria criado
```

```bash
MODO=docker sh conectar.sh # forca o container, mesmo com kubectl local
```

```bash
sh destruir.sh -y          # destroi sem pedir confirmacao
```

## Problemas comuns

**`error: You must be logged in to the server (Unauthorized)`**
Acontecia porque o cluster so reconhecia quem estava no ConfigMap `aws-auth`.
O `main.tf` atual usa EKS Access Entries com
`bootstrap_cluster_creator_admin_permissions = true`, entao quem roda o
`terraform apply` ja entra como administrador. Se outra role precisa de acesso,
adicione em `extra_admin_role_names` (veja `variables.tf`).

**`Your local changes to the following files would be overwritten by merge`**
Use `sh atualizar.sh` em vez de `git pull`.

**As credenciais expiraram no meio do lab**
No AWS Academy elas sao temporarias. Rode `sh config_credenciais.sh` de novo e
repita o comando que falhou - o terraform continua de onde parou.

**Pods em `Pending` com `pod has unbound immediate PersistentVolumeClaims`**
O pod espera um disco que ninguem cria. Desde o EKS 1.23 o provisionador de
EBS virou um driver CSI que **nao vem instalado**. Atinge qualquer StatefulSet
(Dynatrace ActiveGate, bancos, Prometheus). O default do lab ja instala o
addon; se o cluster e anterior a esta mudanca:

```bash
sh diagnostico.sh
```

Se faltar o driver, garanta `habilitar_ebs_csi = true` e rode `sh iniciar.sh`.
Se o diagnostico disser `StorageClass default: NENHUMA`, rode tambem:

```bash
sh storage.sh
```

Para os PVCs que ja estao `Pending`, ha dois casos, e o `storage.sh` diz qual
e o seu:

- `storageClassName` **ausente**: desde o Kubernetes 1.28 a default e atribuida
  retroativamente, e o PVC liga sozinho em instantes;
- `storageClassName: ""`: significa "nao provisione nada, so ligue a um PV
  existente". Esse nunca recebe a default, e o campo e imutavel - o PVC
  precisa ser apagado para o StatefulSet recria-lo.

**O apply fica parado em `aws_eks_node_group.demo: Still creating...`**
A criacao normal leva 3 a 5 minutos. Passou disso, os nos nao estao
conseguindo entrar no cluster. O motivo nao aparece no log do terraform: fica
em `health.issues` do node group e nas *scaling activities* do Auto Scaling
Group. **Sem matar o terraform**, em outro terminal:

```bash
sh diagnostico.sh
```

A secao 0 nao depende de `kubectl` nem de nos existirem - justamente o caso
aqui. Causas comuns:

| Mensagem na scaling activity | Causa |
|---|---|
| `requested more vCPU capacity than your current vCPU limit` | quota de vCPU da conta estourada |
| `not authorized to perform: ec2:RunInstances` | tipo de instancia bloqueado por politica da conta |
| `InsufficientInstanceCapacity` | a AZ ficou sem capacidade daquele tipo |
| ASG lanca mas o no some | o no sobe e nao registra: rede sem saida para o endpoint do EKS ou para o ECR |

Se for quota, reduza no `terraform.tfvars`:

```hcl
node_desired_size = 2
```

O terraform desiste em `node_group_timeout` (25 min por default, contra os 60
do provider).

**O apply falha no `aws_eks_addon.ebs_csi`**
O addon e o **ultimo** recurso do apply, entao o cluster e os workers ja estao
prontos quando ele falha - o `iniciar.sh` diz isso explicitamente. O terraform
nao mostra o motivo, so `Still creating...` ate o `ebs_csi_timeout` (8 min por
default, contra os 20 do provider). O motivo fica em `health.issues`:

```bash
sh ebs_csi.sh --status
```

Esse comando funciona a qualquer momento, inclusive em outro terminal com o
terraform ainda rodando. Ele consulta `health.issues` e mostra tambem os pods
do driver, os eventos e os logs.

Como ler o resultado:

| `health.issues` / estado do pod | Significado |
|---|---|
| `InsufficientNumberOfReplicas` + pod `Pending` | nao ha onde agendar; veja `kubectl describe pod` |
| `ImagePullBackOff` | o no nao alcanca o ECR; cheque a role dos nos |
| `AccessDenied` nos logs | a role dos nos nao pode mexer em volumes EBS |
| `ConfigurationConflict` | ja existe uma instalacao manual do driver no cluster |

Para tentar de novo:

```bash
sh iniciar.sh
```

Se o addon estiver atrapalhando uma turma a comecar, tire-o do apply com
`habilitar_ebs_csi = false` no `terraform.tfvars` e instale depois com
`sh ebs_csi.sh`. **Nao use as duas formas juntas**: com o addon ja criado pelo
script, o terraform falha com `ResourceInUseException`. Se isso acontecer,
importe:

```bash
terraform import 'aws_eks_addon.ebs_csi[0]' eksfiap:aws-ebs-csi-driver
```

**`FailedMount: hostPath type check failed, /sys/kernel/security/apparmor`**
A carga monta um caminho de AppArmor que nao existe na AMI dos nos (a AL2023
usa SELinux). Nao da para resolver pelo Terraform: e configuracao de quem
pede o mount. No Dynatrace, o caminho fica em `.spec.kspm.mappedHostPaths` do
DynaKube e precisa ser removido **em cada DynaKube do namespace**.

**Pods em `Pending` com `0/2 nodes are available: Insufficient memory`**
Os nos sao pequenos demais para a carga. O default ja e `t3.large` (8 GiB);
se ainda faltar memoria, aumente os nos ou a quantidade:

```hcl
node_instance_types = ["t3.xlarge"]
node_desired_size   = 3
```

Lembre que aumentar `max_size` sozinho nao resolve: veja a secao
"Escala automatica" acima.

**`kubectl: line 1: syntax error near unexpected token '<'`**
O `kubectl` da maquina nao e um binario: e uma pagina de erro XML
(`<Error><Code>NoSuchKey</Code>...`) gravada no lugar dele. Acontece quando o
download veio do bucket legado `storage.googleapis.com/kubernetes-release`,
que esta **congelado na v1.31.0** e devolve 404 para qualquer versao a partir
da v1.32.0 - e o `curl` nao usou `--fail`, entao gravou o corpo do erro.

```bash
sh instalar_kubectl.sh
```

O script baixa de `dl.k8s.io` na versao compativel com o seu cluster, confere
o checksum e so substitui o binario depois de testa-lo. A causa raiz estava no
`ansible/ansible_k8s.yml`, que provisiona a VM do lab, e ja foi corrigida.

**`exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"`**
A imagem publicada do `kubectl` foi construida com uma AWS CLI antiga. Duas
saidas:

```bash
MODO=host sh conectar.sh        # se a maquina tem aws + kubectl
```

```bash
sh build_imagem.sh              # reconstroi a imagem localmente
```

Depois do `build_imagem.sh`, o `sh conectar.sh` usa a imagem local
automaticamente. `EKS_BUILD=1 sh conectar.sh` forca a reconstrucao.

**O `destruir.sh` reclama de `DependencyViolation`**
Algum `Service type=LoadBalancer` ainda existe. Apague os Services antes
(`kubectl delete svc --all`) e rode `sh destruir.sh` novamente. O script ja
tenta remover os load balancers automaticamente.

## Caminho alternativo (sem Terraform)

```bash
sh awscli_eks_create.sh
```

```bash
sh awscli_eks_delete.sh
```

Criam o mesmo ambiente so com a AWS CLI. Util para mostrar em aula o que o
Terraform faz por baixo. Os dois caminhos usam o nome `eksfiap`, portanto
**nao rode os dois ao mesmo tempo**.

## Arquivos

| Arquivo | Para que serve |
|---|---|
| `atualizar.sh` | `git pull` preservando credenciais |
| `config_credenciais.sh` | grava `files/credentials` |
| `iniciar.sh` / `preparar.sh` | cria o ambiente |
| `conectar.sh` / `kubectl.sh` | abre o shell com `kubectl` |
| `destruir.sh` | remove o ambiente |
| `main.tf` / `variables.tf` / `outputs.tf` | definicao do cluster |
| `config_eks_iam.sh` | cria as roles IAM em conta propria (nao e preciso no AWS Academy) |
| `awscli_eks_create.sh` / `awscli_eks_delete.sh` | caminho alternativo via AWS CLI |
| `delete_vpc.sh` | limpeza manual de VPC ([lianghong/delete_vpc](https://github.com/lianghong/delete_vpc)) |
| `cloud9_kubectl.sh` | configura o `kubectl` local sem abrir shell novo |
| `diagnostico.sh` | coleta somente-leitura do estado do cluster |
| `ebs_csi.sh` | diagnostica o driver de disco (`--status`), instala/remove |
| `storage.sh` | garante uma StorageClass default (gp3) |
| `autoscaler.sh` | instala/remove o Cluster Autoscaler |
| `instalar_kubectl.sh` | (re)instala o `kubectl` na versao do cluster |
| `build_imagem.sh` | constroi a imagem do `kubectl` localmente |
| `lib_versao.sh` | resolve a versao do `kubectl` (usado pelos dois acima) |
| `files/Dockerfile` | imagem `tonanuvem/kubectl-aws-cli` |
| `bkp/`, `iam/bkp/`, `eksfiap_ajustar` | versoes antigas, mantidas como referencia |

## Referencias

- https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html
- https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster
- https://learn.hashicorp.com/tutorials/terraform/eks

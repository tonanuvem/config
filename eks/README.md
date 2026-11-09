# Lab EKS - cluster Kubernetes gerenciado na AWS

Cria um cluster EKS (`eksfiap`) com 2 nos workers, numa VPC propria, usando
Terraform. Pensado para o AWS Academy / Learner Lab, onde a role `LabRole` e o
key pair `vockey` ja existem.

## Fluxo do lab

```bash
cd config/eks && sh atualizar.sh
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

```bash
sh destruir.sh
```

| Passo | O que faz | Tempo |
|---|---|---|
| `sh atualizar.sh` | `git pull` preservando as credenciais locais | segundos |
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
- managed node group `demo`: 2 x `t3.medium` (min 1, max 4), AMI Amazon
  Linux 2023, disco de 20 GiB.

Custo aproximado em `us-east-1`: ~US$ 0,10/h do control plane + ~US$ 0,08/h dos
2 nos. **Rode `sh destruir.sh` ao terminar.**

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
| `build_imagem.sh` | constroi a imagem do `kubectl` localmente |
| `files/Dockerfile` | imagem `tonanuvem/kubectl-aws-cli` |
| `bkp/`, `iam/bkp/`, `eksfiap_ajustar` | versoes antigas, mantidas como referencia |

## Referencias

- https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html
- https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster
- https://learn.hashicorp.com/tutorials/terraform/eks

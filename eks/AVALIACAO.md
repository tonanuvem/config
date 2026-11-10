# Avaliacao do lab EKS e melhorias aplicadas

Avaliacao do fluxo descrito:

```
cd config/eks && git pull
sh config_credenciais.sh
sh iniciar.sh      # ~15 min
sh conectar.sh     # abre um bash com kubectl configurado
```

O fluxo esta correto como roteiro de aula. Os problemas encontrados nao estao
no desenho dos 4 passos, e sim no fato de que **varios deles so funcionam na
primeira execucao** e de que falhas aparecem tarde (depois de 10 minutos de
espera). Abaixo, o que foi encontrado, em ordem de impacto.

---

## 1. O passo 1 (`git pull`) quebrava a partir da segunda execucao

Dois scripts escreviam dentro de arquivos **versionados**:

- `preparar.sh` fazia `sed -i 's|497573848553|'$ACCOUNT'|' main.tf`, isto e,
  reescrevia o `main.tf` com o Account ID do aluno;
- `config_credenciais.sh` gravava as credenciais em `files/credentials`, que
  estava no `git ls-files`.

Resultado, na segunda aula com o mesmo clone:

```
error: Your local changes to the following files would be overwritten by merge:
        eks/main.tf
        eks/files/credentials
Please commit your changes or stash them before you merge.
```

O aluno travava no passo 1.

**O que foi feito**

- o Account ID saiu do `main.tf`. As roles agora vem de
  `data "aws_iam_role"`, e o ARN e montado com `data.aws_caller_identity` e
  `data.aws_partition`. Nao existe mais `sed` em arquivo versionado;
- `eks/files/credentials` foi removido do versionamento (`git rm --cached`) e
  entrou no `.gitignore`, junto com `eks/files/kube/`, `eks/awscli/`,
  `eks/bkp_awscli_*/` e `eks/terraform.tfvars`. Ficou um
  `files/credentials.example` apenas com o formato;
- novo `atualizar.sh`: guarda as credenciais, descarta **somente** as
  alteracoes feitas por script (`main.tf`, `files/credentials`), faz o `git
  pull` e devolve as credenciais. E o novo passo 1.

**Ressalva da transicao:** um clone criado antes destas mudancas nao tem o
`atualizar.sh`, portanto a primeira atualizacao ainda precisa de um comando
manual, documentado no `README.md`:

```
git checkout -- main.tf files/credentials && git pull
```

Perder o `files/credentials` nesse momento e inofensivo, porque o passo
seguinte do lab o regrava. Da segunda vez em diante, o `atualizar.sh` resolve.
Reproduzi a falha e validei este comando em um clone de teste.

> Credenciais da AWS versionadas sao o achado mais serio aqui. O arquivo
> rastreado estava vazio no repositorio, mas qualquer `git commit -a` depois de
> `config_credenciais.sh` publicaria chaves reais. Agora o arquivo e ignorado e
> gravado com permissao 600.

## 2. `config_credenciais.sh` e `iniciar.sh` nao conversavam

`config_credenciais.sh` gravava em `./files/credentials`, usado **so** pelo
container do `kubectl`. Ja o `preparar.sh` rodava `aws` e `terraform` na
maquina, que leem `~/.aws/credentials`. Ou seja: colar as credenciais no passo
2 nao habilitava o passo 3. Funcionava apenas em ambientes que ja tinham
credencial por fora (CloudShell).

**O que foi feito:** o `preparar.sh` exporta
`AWS_SHARED_CREDENTIALS_FILE=$PWD/files/credentials` quando o arquivo esta
preenchido e nao ha `AWS_ACCESS_KEY_ID` no ambiente. Os dois passos passam a
usar a mesma credencial, sem alterar o `~/.aws` do usuario.

## 3. Erros apareciam 10 minutos depois do que deviam

Nao havia verificacao previa nenhuma, e `preparar.sh` nao tinha `set -e`: se
`aws sts get-caller-identity` falhasse, o script seguia ate o `terraform
apply` e quebrava la.

O caso pior era o key pair: `remote_access { ec2_ssh_key = "vockey" }` so e
avaliado na criacao do **node group**, que acontece *depois* do control plane.
Numa conta sem a chave `vockey`, o apply falhava por volta do minuto 11.

**O que foi feito:** `preparar.sh` virou um passo de verificacao em 5 etapas,
com `set -euo pipefail`:

1. `aws` e `terraform` instalados;
2. credenciais validas (`sts get-caller-identity`), com a conta e a identidade
   impressas;
3. role IAM existe; key pair existe (se nao, avisa e cria o node group **sem**
   SSH, em vez de falhar); nao ha cluster homonimo fora do estado do terraform;
   `main.tf` nao esta sujo;
4. `terraform init`;
5. `terraform apply`, com o tempo total medido no final.

Tambem aceita `sh iniciar.sh --check` (so verifica) e `--plan` (so mostra).

## 4. `conectar.sh` falhava na segunda vez

`kubectl.sh` fazia `docker run -d --name kubectl ... /bin/sh` e depois
`docker exec`. Como o processo principal era um shell interativo detached, o
container **continuava rodando** depois que o aluno digitava `exit`. Na
segunda execucao:

```
docker: Error response from daemon: Conflict. The container name "/kubectl"
is already in use by container ...
```

Alem disso: a pasta `./files` inteira (com `Dockerfile` e `README.md`) era
montada como `/root/.aws`; o kubeconfig era descartado a cada saida; e se o
daemon do Docker estivesse parado, o erro era um `docker exec` cru.

**O que foi feito**

- uma unica execucao `docker run -ti --rm`, que faz `update-kubeconfig`,
  mostra o endpoint e os nos, e **so depois** entra no shell. Ao sair, o
  container e removido. Sobras de execucoes anteriores sao limpas antes, e um
  `trap` garante a limpeza;
- monta so o arquivo de credenciais (`:ro`) e persiste o kubeconfig em
  `files/kube/`, sem tocar no `~/.kube/config`;
- verifica o daemon do Docker e o estado do cluster antes de tentar conectar;
- **novo modo `host`**: se a maquina tem `aws` e `kubectl` (CloudShell, Cloud9),
  dispensa o Docker. `MODO=auto` (default) escolhe sozinho;
  `MODO=docker sh conectar.sh` forca o container.

## 5. A imagem do `kubectl` e uma bomba de tempo

`files/Dockerfile` fixava `awscli==1.19.21` (marco/2021) e baixava o `kubectl`
de `stable.txt` (sempre o mais recente). AWS CLI dessa epoca gera kubeconfig
com `client.authentication.k8s.io/v1alpha1`, removida no Kubernetes 1.24.
Qualquer rebuild recente da imagem produz:

```
error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"
```

E o `pip install awscli` nem roda mais no Alpine atual (PEP 668). O
`apk del py-pip` tambem nunca removeu nada: no Alpine o pacote chama-se
`py3-pip`.

**O que foi feito:** Dockerfile reescrito com `apk add aws-cli` (AWS CLI v2) e
`kubectl` em versao fixa via `ARG KUBECTL_VERSION`.

Corrigir o Dockerfile, no entanto, **nao resolve nada por si so**: o
`kubectl.sh` fazia `docker pull tonanuvem/kubectl-aws-cli`, ou seja, continuava
baixando a imagem publicada, construida em 2021. Enquanto ninguem reconstruisse
e publicasse, o aluno no modo docker seguia recebendo exatamente a imagem com o
defeito. Faltava o build local - lacuna fechada depois:

- novo `build_imagem.sh`: constroi a partir de `./files`, com
  `--build-arg KUBECTL_VERSION`, na tag local
  `eks-lab/kubectl-aws-cli:local`, e **so termina depois de conferir** que
  `aws --version` e `kubectl version --client` respondem dentro da imagem (o
  defeito original era justamente uma imagem que construia e falhava em uso);
- `kubectl.sh` passou a escolher a imagem nesta ordem: `EKS_IMAGE` (se o
  usuario indicou uma), `EKS_BUILD=1` (forca o build), imagem local ja
  construida, imagem publicada ja baixada, e por fim `docker pull` - **que ao
  falhar cai para o build local** em vez de abortar.

**O build da imagem nao pode ser executado neste ambiente** (sem daemon Docker,
e o indice de pacotes do Alpine bloqueado pela politica de rede). A logica de
escolha de imagem foi testada com um `docker` simulado, nos seis caminhos. O
`docker build` em si continua por verificar - e por isso o `build_imagem.sh`
embute a propria verificacao. O modo `host` do `conectar.sh` dispensa a imagem
por completo em CloudShell.

## 6. `main.tf`: correcoes de infraestrutura

| Achado | Impacto | Correcao |
|---|---|---|
| `enable_dns_hostnames` comentado (estava ativo no `bkp/vpc.tf`) | o EKS exige DNS na VPC; nos podem nao registrar | `enable_dns_support` e `enable_dns_hostnames` ativos |
| subnets sem a tag `kubernetes.io/role/elb` | `Service type=LoadBalancer` nao descobre as subnets | tag adicionada |
| `aws_lb "lb_eks"` - um Network Load Balancer | criado e **nunca usado**: custa ~US$ 16/mes e trava a exclusao da VPC | removido |
| `aws_network_interface "eni_eks"` x2 | ENIs orfas que seguram as subnets no destroy | removidas |
| provider AWS sem restricao de versao | o lab quebra sozinho quando sai uma major | `~> 5.100` (a 6.x tem breaking changes) |
| `required_version = ">= 0.12"` | permite sintaxe que o codigo nao usa mais | `>= 1.3` |
| sem `access_config` | causa do `You must be logged in to the server (Unauthorized)` citado nos comentarios do proprio `preparar.sh` | `authentication_mode = API_AND_CONFIG_MAP` + `bootstrap_cluster_creator_admin_permissions = true`, e `extra_admin_role_names` para liberar outras roles |
| node group sem `ami_type` | cai no default; AMIs Amazon Linux 2 estao em fim de vida no EKS | `AL2023_x86_64_STANDARD` |
| tudo fixo no codigo (tipo de instancia, tamanhos, CIDR, chave SSH) | nao da para variar em aula sem editar `.tf` | 20 variaveis documentadas em `variables.tf`, todos os defaults iguais ao comportamento anterior |
| AZs sem filtro | Local Zones nao suportam EKS | filtro `opt-in-status=opt-in-not-required` |
| `CLUSTER_NAME=x sh iniciar.sh` | mudava as verificacoes mas o terraform criava `eksfiap` | as variaveis de ambiente, quando definidas, viram `-var` |

O security group continua liberando `0.0.0.0/0` por **default**, para nao
mudar o comportamento em sala, mas agora isso e a variavel
`cluster_ingress_cidrs`, com o risco documentado.

## 7. `outputs.tf` entregava coisas que nao funcionam

- o `kubeconfig` exportado usava `aws-iam-authenticator` e
  `client.authentication.k8s.io/v1alpha1` - binario nao instalado em lugar
  nenhum do lab, apiVersion removida no Kubernetes 1.24;
- o `config_map_aws_auth` tinha `rolearn: "arn:aws:iam::*:role/..."`, e
  curinga nao e ARN valido. Com access entries, nem e mais necessario.

Trocados por outputs uteis: `cluster_endpoint`, `cluster_version`,
`cluster_security_group_id` (o SG onde se libera NodePort), `vpc_id`,
`subnet_ids`, `aws_account_id` e `kubeconfig_command`.

## 8. `destruir.sh` corrompia o estado do terraform

A ordem era: apagar a VPC por fora (`delete_vpc.sh`) e **depois**
`terraform destroy`. O estado ficava apontando para recursos inexistentes, e o
destroy terminava com erro ou deixando lixo no `tfstate`.

**O que foi feito:** ordem invertida - remove os load balancers criados pelo
Kubernetes, roda `terraform destroy` e, **so se a VPC sobreviver**, usa o
`delete_vpc.sh` como plano B e realinha o estado. Ganhou confirmacao (`-y`
pula), regiao e nome de cluster parametrizados.

Detalhe que faltava: um `Service type=LoadBalancer` no EKS cria, por default,
um **Classic** Load Balancer, e o `delete_vpc.sh` trata apenas `elbv2`
(ALB/NLB). O CLB ficava para tras segurando ENIs - causa classica de
`DependencyViolation`. O `destruir.sh` agora apaga os dois tipos.

## 9. O caminho `awscli_eks_*.sh` nao conseguia subir nos

Nao e o caminho principal do lab, mas estava quebrado:

- a VPC era criada **sem Internet Gateway e sem route table**, e as subnets sem
  IP publico. Sem rota de saida os nos nao alcancam o endpoint do EKS nem o
  ECR, e nunca se registram no cluster;
- sem `enable-dns-hostnames` na VPC;
- `if [ -f "./awscli/" ]` testa um diretorio com `-f`: sempre falso, logo o
  `mkdir` rodava mesmo com ambiente antigo no lugar;
- as esperas eram fixas: `for tempo in $(seq 1 100); do sleep 5; done` = 500s
  para o cluster e 400s para o node group, **mesmo quando ficavam prontos
  antes**;
- no delete, `while ... | grep DELETING` deixava de funcionar assim que o
  recurso sumia (o `describe` passa a dar erro), e `read ERRO` com
  `[ $ERRO -eq 0 ]` quebrava o script se o usuario apertasse apenas ENTER.

Todos corrigidos; as esperas fixas viraram `aws eks wait cluster-active` /
`nodegroup-active` / `*-deleted`.

## 10. Outros ajustes

- `config_eks_iam.sh`: mesma colisao de nome de container
  (`docker run -d --name awscli` + varios `exec`); `EXEC` definida e nunca
  usada; `$PWD` sem aspas; `create-role` abortava com `EntityAlreadyExists` na
  segunda execucao. Reescrito: uma execucao, idempotente, e funciona sem Docker
  se a AWS CLI estiver instalada;
- `config_credenciais.sh`: valida o que foi colado (vazio, faltando
  `aws_access_key_id`/`aws_secret_access_key`), adiciona `[default]` se faltar,
  avisa se nao houver `aws_session_token`, grava com permissao 600 e mostra so
  os ultimos digitos do Access Key ID;
- `iniciar.sh`/`conectar.sh` viraram wrappers POSIX que reexecutam em `bash`
  (os scripts usam `[[ ]]`, arrays e `pipefail`, que `sh` nao tem);
- `cloud9_kubectl.sh` parametrizado;
- `eks/README.md` reescrito com o fluxo, o que e criado, custo aproximado,
  como personalizar e uma secao de problemas comuns.

---

## 11. Bug encontrado na primeira execucao real (kubectl quebrado na VM)

Na primeira execucao do lab em uma VM real, o `sh iniciar.sh` funcionou (cluster
criado em 13m50s, versao **1.37**), mas o `sh conectar.sh` deu:

```
/usr/local/bin/kubectl: line 1: syntax error near unexpected token `<'
/usr/local/bin/kubectl: line 1: `<?xml version='1.0' ...><Error><Code>NoSuchKey</Code>
  ...No such object: kubernetes-release/release/v1.37.2/bin/linux/amd64/kubectl</Error>'
(os nos podem levar alguns minutos para aparecer)
```

Tres defeitos distintos, encadeados.

### 11.1 Causa raiz: bucket legado congelado (`ansible/ansible_k8s.yml`)

O playbook que provisiona a VM do lab baixava `kubeadm`, `kubelet` e `kubectl`
de `https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/...`.
Esse bucket **esta congelado**. Verificado:

| URL | Resultado |
|---|---|
| `kubernetes-release/release/stable.txt` | `v1.31.0` |
| `kubernetes-release/.../v1.31.0/bin/linux/amd64/kubectl` | HTTP 200 |
| `kubernetes-release/.../v1.32.0/bin/linux/amd64/kubectl` | HTTP 404 |
| `dl.k8s.io/release/v1.37.2/bin/linux/amd64/kubectl` | HTTP 200 |

O commit `ef99e09` ("Atualiza stack shift para ... K8s 1.37") subiu o
`RELEASE` para `v1.37.2` mas manteve a URL antiga. A partir da v1.32.0 nao
existe nada lá.

### 11.2 O que transformou um 404 em binario corrompido

```
sudo curl -L --remote-name-all https://storage.googleapis.com/...
sudo chmod +x {kubeadm,kubelet,kubectl}
```

Sem `--fail`, o `curl` grava o corpo da resposta de erro - o XML - dentro dos
arquivos. O `chmod +x` os torna "executaveis", e a falha so aparece no
primeiro uso. **Os tres binarios foram afetados**, nao so o `kubectl`.

Corrigido: URL para `dl.k8s.io`, `curl -fL`, e `kubectl version --client` /
`kubeadm version` no fim da task, para a falha aparecer no provisionamento.
A mesma URL legada foi corrigida em `ansible/k8s_version_install.yaml` e nas
linhas comentadas de `aws-vm/config.sh` e `bkp_preparar.sh`, para nao voltar.

### 11.3 Defeito meu: o erro foi disfarcado de "aguarde"

O `kubectl.sh` que eu escrevi fazia:

```
kubectl get nodes || echo "(os nos podem levar alguns minutos para aparecer)"
```

Esse `||` transformava **qualquer** falha - binario corrompido, credencial
invalida, cluster inacessivel - na mensagem tranquilizadora de que os nos
ainda estavam subindo, e seguia abrindo o shell. Foi exatamente o que apareceu
no log acima, logo abaixo do erro real.

Agora o script confere `kubectl version --client` antes de usar o `kubectl`;
se o arquivo comeca com `<`, diz que nao e um binario, mostra o inicio do
conteudo, explica a origem e aponta o `instalar_kubectl.sh`. E separa os casos
de `get nodes`: `No resources found` (espera legitima) de erro real, que e
impresso em vez de engolido. Os quatro cenarios foram testados.

### 11.4 Defeito meu: kubectl fixo saiu do skew

Como deixei `cluster_version = null`, o EKS criou o cluster na sua versao
default - **1.37**. Mas meu `files/Dockerfile` fixava `KUBECTL_VERSION=v1.33.3`:
quatro minors de distancia, fora do skew suportado (+-1).

Um pino fixo no codigo envelhece sozinho. Novo `lib_versao.sh` resolve a
versao na ordem: `KUBECTL_VERSION` explicita > versao do cluster
(`stable-<minor>.txt`) > `stable.txt`. Usado pelo `instalar_kubectl.sh` e pelo
`build_imagem.sh`.

### 11.5 Licao

As duas falhas minhas sao da mesma familia: **tratar erro sem distinguir qual
erro**. O `|| echo` no `get nodes` e o `curl` sem `--fail` fazem a mesma coisa
em niveis diferentes - seguem adiante como se tivesse dado certo. O `--fail`
faltando custou um binario corrompido; o `||` faltando custou o diagnostico.

---

## 12. Dimensionamento dos nos e escala automatica

Na primeira aula com carga real (Dynatrace: operator, OneAgent como DaemonSet
e ActiveGate como StatefulSet), 6 dos 20 pods ficaram `Pending`:

```
FailedScheduling: 0/2 nodes are available: 2 Insufficient memory.
preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
```

Diagnostico: memoria, nao quantidade de pods. `t3.medium` tem 4 GiB, dos quais
sobram ~3 GiB alocaveis; o limite de pods por no (17 em `t3.medium`) nem chegou
a ser atingido, ja que 2 nos dariam 34 vagas para 20 pods.

### 12.1 t3.large, nao t2.large

| | vCPU | Memoria | Preco sob demanda (us-east-1) |
|---|---|---|---|
| `t3.medium` (antes) | 2 | 4 GiB | ~US$ 0,0416/h |
| `t2.large` (proposto) | 2 | 8 GiB | ~US$ 0,0928/h |
| **`t3.large` (adotado)** | 2 | 8 GiB | **~US$ 0,0832/h** |

Mesma CPU e memoria da `t2.large`, geracao mais nova, melhor baseline de burst
e ~10% mais barata. Nao ha cenario neste lab em que a `t2.large` seja melhor.
Quem quiser cortar mais usa `node_capacity_type = "SPOT"`.

### 12.2 `scaling_config` nao e escala automatica

Vale corrigir a expectativa de "habilitar o autoscaling no terraform via config
da criacao do cluster": **esse botao nao existe**. O bloco

```hcl
scaling_config {
  min_size = 2
  max_size = 4
}
```

apenas define os limites do Auto Scaling Group. Nada observa pods `Pending` e
nada cria nos. Com `max_size = 4` e sem controlador, os 6 pods do print
continuariam `Pending` indefinidamente. Escala automatica de verdade exige o
**Cluster Autoscaler** (ou o Karpenter), que e um Deployment dentro do cluster.

E ha uma armadilha a mais: o autoscaler descobre node groups por tags no ASG, e
**as tags de `aws_eks_node_group.tags` nao sao propagadas para o ASG**. Precisam
ser aplicadas com `aws_autoscaling_group_tag`.

### 12.3 O que foi implementado

- defaults: `t3.large`, `min_size = 2`, `desired_size = 2`, `max_size = 4`;
- `habilitar_autoscaler` (default `false`) aplica no ASG as tags
  `k8s.io/cluster-autoscaler/enabled` e `k8s.io/cluster-autoscaler/<cluster>`
  via `aws_autoscaling_group_tag`;
- novo `autoscaler.sh`, que descobre a release do autoscaler correspondente a
  minor do cluster, baixa o manifesto oficial daquela tag, substitui o nome do
  cluster e a imagem (o exemplo oficial fixa `v1.32.1` mesmo nas tags novas),
  aplica, confere o rollout e inspeciona os logs em busca de erro de permissao;
- `output "node_group_asg_name"`, para inspecionar o ASG.

Observacao registrada no README: com o autoscaler ativo, o `desired_size` passa
a ser dele; um `terraform apply` posterior devolve `node_desired_size` e o
autoscaler torna a subir os nos.

### 12.4 O que foi testado

Verificado contra a rede real: a release `cluster-autoscaler-1.37.0` existe
(`1.38.0` ainda nao), o manifesto daquela tag baixa, e a substituicao produz
`image: ...cluster-autoscaler:v1.37.0` com o nome do cluster no
`--node-group-auto-discovery`, em 6 documentos YAML validos. Os caminhos de
erro do `autoscaler.sh` (argumento invalido, `kubectl` ausente, tags faltando
no ASG) foram testados com simuladores. O terraform passa em `validate`.

**Nao testado:** a instalacao do autoscaler em um cluster de verdade, e,
portanto, se a `LabRole` tem as permissoes de `autoscaling` necessarias. E o
primeiro ponto a conferir ao rodar `sh autoscaler.sh`.

---

## 13. Armazenamento: PVC sem provisionador

Depois de resolver a memoria, o ActiveGate voltou a ficar `Pending`, com outro
motivo:

```
0/2 nodes are available: pod has unbound immediate PersistentVolumeClaims
```

Causa: desde o **EKS 1.23** o provisionador de EBS saiu do Kubernetes e virou
um driver CSI que **nao vem instalado no cluster**. Sem ele nenhum PVC de
disco e atendido, o PVC fica `Pending` e o pod nunca agenda. Atinge qualquer
StatefulSet - ActiveGate, bancos de dados, Prometheus.

O lab nunca tinha esbarrado nisso porque so rodava cargas sem estado.

Implementado:

- `aws_eks_addon "aws-ebs-csi-driver"`, com `habilitar_ebs_csi` default `true`
  e `depends_on` do node group (o driver roda nos nos);
- `ebs_csi_service_account_role_arn` para quem usa IRSA; no AWS Academy fica
  `null` e o driver usa as permissoes da role dos nos;
- `storage.sh`, para o caso de nao haver StorageClass default: cria uma `gp3`
  com `WaitForFirstConsumer` (com `Immediate` o volume pode nascer numa AZ sem
  vaga e o pod nunca agenda), criptografada, e tira o default das demais;
- `diagnostico.sh`, coleta somente-leitura: nos e AMI, requests por no, pods
  pendentes com os eventos, StorageClasses e qual e a default, PVCs/PVs,
  drivers CSI, addons do EKS, hostPaths dos DaemonSets e eventos de Warning.

## 14. `FailedMount` do AppArmor: fora do alcance do Terraform

O segundo erro do mesmo dia:

```
MountVolume.SetUp failed for volume "node-path-5": hostPath type check failed,
/sys/kernel/security/apparmor is not a directory ... does not exist
```

Isto **nao e um problema do cluster nem do Terraform**: e uma carga pedindo um
hostPath que nao existe na AMI dos nos. O caminho so existe onde o LSM AppArmor
esta ativo (familia Debian/Ubuntu/SUSE); a AL2023 usa SELinux. Nenhum
`ami_type` de managed node group do EKS (AL2023, Bottlerocket) traz AppArmor -
exigiria AMI customizada de Ubuntu, o que seria um preco alto para o lab.

A correcao pertence a configuracao do Dynatrace: remover o caminho de
`.spec.kspm.mappedHostPaths` do DynaKube. Registrado no README como
troubleshooting, com a ressalva de que precisa ser feito **em cada DynaKube do
namespace** - um script que escolhe apenas um deixa os demais quebrados.

Ressalva de honestidade: nao consegui confirmar em fonte oficial que a AL2023
nao ativa AppArmor. O `diagnostico.sh` mostra o `OS-IMAGE` dos nos e os
hostPaths dos DaemonSets, que e o que confirma o diagnostico no cluster real.

**Confirmado depois, no cluster:** os nos rodam `Amazon Linux 2023.12`, e a
remocao do caminho do DynaKube resolveu - o DaemonSet
`node-config-collector` voltou a 2/2 e seus hostPaths passaram a ser
`/boot /etc /proc/sys/kernel /sys/fs /usr/lib/systemd/system /var/lib`, sem o
caminho do AppArmor. Os eventos de `FailedMount` que ainda apareciam eram
anteriores a correcao.

## 15. O que o diagnostico no cluster real mostrou

Rodado apos a troca para `t3.large`:

- **memoria deixou de ser o gargalo**: 7,1 GiB alocaveis por no, com requests
  de 11% e 19%. O aperto passou a ser de CPU em um dos nos (77%);
- **unico bloqueio restante: armazenamento**. Tres replicas do ActiveGate do
  DynaKube `...-agents` presas em `Pending` ha 95 minutos, com os PVCs
  `ag-tmp-gateway-*` em `Pending` e o evento do controlador sendo explicito:
  `no persistent volumes available for this claim and no storage class is set`;
- **nenhum addon gerenciado no cluster**: `aws eks list-addons` voltou vazio.
  O `coredns`, o `kube-proxy` e o `vpc-cni` rodam como auto-gerenciados, que e
  o que o EKS instala quando o cluster e criado sem addons declarados. Nao ha
  driver de EBS, so `efs.csi.aws.com` e o CSI do proprio Dynatrace;
- **a unica StorageClass e a `gp2` com o provisionador antigo**
  `kubernetes.io/aws-ebs`, e **nenhuma esta marcada como default**. Duas
  razoes somadas para o PVC nunca ser atendido.

Isso confirmou as duas correcoes do item 13 e acrescentou uma distincao que
faltava no `storage.sh`: um PVC com `storageClassName` ausente recebe a default
retroativamente (GA no Kubernetes 1.28), enquanto um com `storageClassName: ""`
nunca recebe e precisa ser recriado. O script agora classifica cada PVC
pendente nesses dois casos e so manda apagar os que realmente precisam.

Fica como melhoria possivel, nao aplicada: declarar `coredns`, `kube-proxy` e
`vpc-cni` como `aws_eks_addon`, em vez de deixa-los auto-gerenciados. Daria
controle de versao sobre eles, ao custo de mais alguns minutos no apply.

---

## 16. Quantidade de nos: 3 em vez de 2

Depois da troca para `t3.large`, a pergunta passou a ser quantos nos. Com os
numeros medidos no cluster real (2 x `t3.large`, 1930m e ~6,9 GiB alocaveis
por no):

| | CPU (requests) | Memoria (requests) |
|---|---|---|
| no 1 | 1490m (77%) | 0,83 GiB (12%) |
| no 2 | 690m (36%) | 1,38 GiB (20%) |
| total, 2 nos | 56% | 16% |
| total, 3 nos | 38% | 11% |

O gargalo deixou de ser memoria (16%) e passou a ser **CPU**, concentrada: 77%
em um no, com apenas 440m livres ali. Tres razoes para o terceiro no:

1. **folga de CPU** onde ela acabou, nao onde ja sobrava;
2. **o controlador do driver de EBS** sobe 2 replicas com anti-afinidade entre
   nos; com um no quase cheio, ele fica `Pending` e o addon nunca fica
   saudavel - foi o que travou o `terraform apply` em `Still creating...`;
3. **terceiro dominio de falha**: um StatefulSet de 3 replicas que exija
   anti-afinidade (o ActiveGate do DynaKube `-agents` pede 3) **nunca** agenda
   por completo em 2 nos, por mais CPU que sobre.

Custo: 3 x `t3.large` ~US$ 0,25/h, contra ~US$ 0,17/h com 2. Vale comparar com
a alternativa de nos maiores: 2 x `t3.xlarge` custam ~US$ 0,33/h, mais caro e
com um dominio de falha a menos.

`node_desired_size` passa a 3 por default, com `min_size` 2 e `max_size` 4. Um
lab sem stack de observabilidade continua bem servido por 2, e o README diz
como voltar.

---

## 17. O addon do EBS nao pode bloquear a criacao do cluster

Na execucao real, o `aws_eks_addon.ebs_csi` ficou em `Still creating...` por
mais de 15 minutos, duas vezes. O addon **era criado** na AWS
(`v1.67.2-eksbuild.1`, com `created_at` e `modified_at` preenchidos), mas nunca
chegava a `ACTIVE`, e o terraform esperava calado ate o timeout de 20 minutos -
derrubando o apply inteiro, inclusive o que ja tinha dado certo.

Dois problemas, um meu e um de desenho.

### 17.1 Meu palpite de CPU estava errado

Eu disse que o provavel culpado era CPU, porque um dos nos estava com 77% de
requests. A conta desmente: o `ebs-csi-controller` pede ~60m por replica
(6 containers x 10m), e sobravam 440m no no mais cheio - cabiam 7 replicas.
CPU nao era o gargalo.

### 17.2 O desenho era ruim, independente da causa

O ponto que importa nao e qual era a causa, e sim que **era impossivel
descobri-la durante o apply**. O terraform espera o addon chegar a `ACTIVE` e
nao expoe `health.issues`, que e exatamente onde o EKS diz o que esta errado.
Um recurso opcional, que so importa para cargas com disco, estava no caminho
critico da criacao do cluster.

Primeira correcao, **revertida depois**: tirar o addon do terraform
(`habilitar_ebs_csi = false`) e instala-lo por script. Resolvia o sintoma, mas
ao custo de deixar um pedaco da infraestrutura fora do estado, em um projeto
cujo proposito e ensinar IaC - e criando duas formas de fazer a mesma coisa,
que conflitam entre si (`ResourceInUseException`). O diagnostico nunca dependeu
de quem cria o addon: `--status` consulta a API do EKS, e funciona com o
terraform rodando em outro terminal.

Correcao final: o addon **continua no terraform** (default `true`), com tres
ajustes que atacam a causa do incomodo sem abrir mao do IaC:

- `timeouts` com `ebs_csi_timeout` (default 8 minutos, contra os 20 do
  provider): falha cedo o suficiente para nao perder uma aula;
- `depends_on` do node group deixa o addon como **ultimo** recurso do apply,
  entao, quando ele falha, o cluster e os workers ja estao prontos;
- o `preparar.sh` passa a distinguir os dois casos: consulta o estado do
  cluster e o do addon e, quando so o addon falhou, diz isso em vez de dar a
  impressao de que o lab inteiro quebrou, apontando o `--status` e o
  `conectar.sh`, que ja funciona.

O `ebs_csi.sh` fica como ferramenta de diagnostico e reparo, e ainda instala o
addon para quem optar por `habilitar_ebs_csi = false`. Ele:

- cria o addon e consulta `describe-addon` a cada 10 segundos;
- imprime `health.issues` **assim que aparecem** - um problema vira diagnostico
  em ~1 minuto em vez de 20;
- junto com os issues, mostra os pods do driver, os eventos que explicam por
  que nao ficam prontos e o log do container principal;
- aceita `--status` e `--remover`, para repetir a tentativa sem mexer no
  terraform nem no estado.

A licao e a mesma do item 11.5, num nivel acima: o `|| echo` escondia *qual*
erro era; aqui o desenho escondia *se havia* erro. Mas a primeira correcao
exagerou na dose - tirou o recurso do IaC para resolver um problema de
visibilidade e de timeout, que tinham solucao sem isso. Vale registrar as duas
tentativas: a reacao instintiva a um passo lento foi retira-lo do caminho
critico, quando o que faltava era limitar a espera e saber distinguir o que
falhou.

---

## 18. O mesmo defeito, em outro recurso: node group sem limite

Na execucao seguinte o `aws_eks_node_group.demo` passou de 19 minutos em
`Still creating...` (o normal e 3 a 5; numa execucao anterior levou 2m6s). O
diagnostico do item 17 valia igual aqui, e eu so tinha aplicado ao addon.

Numeros que importam: o timeout default do provider para o node group e de
**60 minutos**, contra 20 do addon. Ou seja, o recurso mais propenso a falhar
por motivos de conta - quota de vCPU, tipo de instancia bloqueado, capacidade
na AZ, rede sem saida - era tambem o que demorava mais a desistir, sem dizer
nada.

Correcao, generalizando o item 17:

- `timeouts` no `aws_eks_node_group`, pela variavel `node_group_timeout`
  (default 25 minutos);
- o `diagnostico.sh` ganhou a **secao 0**, que nao depende de `kubectl` nem de
  nos existirem - exatamente o cenario de um apply travado. Ela mostra o
  estado do cluster, de cada node group com `health.issues` e escala, as
  **scaling activities do ASG** (onde aparece o erro real de lancamento das
  instancias) e as instancias EC2. O resto do script passou a tratar o
  `kubectl` como opcional, em vez de abortar quando ele falta;
- o `preparar.sh` passou a reportar tambem o estado do node group na falha do
  apply, com as causas comuns e a saida imediata (`node_desired_size = 2`);
- `NODE_GROUP_NAME` entrou nas variaveis de ambiente repassadas ao terraform,
  para o diagnostico nao olhar um node group diferente do que foi criado.

A licao, de novo: todo recurso lento do apply precisa de duas coisas - um
limite de espera menor que o default do provider, e um caminho para ver o
estado por fora enquanto espera. Eu tinha tratado isso como um problema do
addon, quando era um padrao do projeto inteiro.

---

## 19. Causa raiz do node group: um processo da conta mata os nos

Tres tentativas, ~35 minutos cada, terminaram em
`NodeCreationFailure: Unhealthy nodes`. A investigacao passou por quatro
hipoteses minhas, todas derrubadas pelos dados - vale registrar a sequencia,
porque o erro de metodo se repetiu.

| Hipotese | O que a derrubou |
|---|---|
| CPU insuficiente para o controlador do EBS | 440m livres no no mais cheio; o controlador pede 60m por replica |
| Quota de vCPU estourada | 15 instancias **lancaram**; quota impediria o lancamento |
| ASG nunca criado | leitura feita cedo demais; o ASG existia |
| Falta da access entry `EC2_LINUX` | consulta feita antes de o node group existir; depois ela aparecia |

A resposta so veio de duas evidencias que nenhuma API do EKS mostra.

**Primeira, o console do no:**

```
[10.50s] nodeadm: done! {"duration": 1.097}
[33.79s] systemd-shutdown[1]: Syncing filesystems and block devices.
[33.87s] systemd-shutdown[1]: Powering off.
[33.99s] ACPI: PM: Preparing to enter system sleep state S5
```

O bootstrap concluiu em 1,1 segundo e a maquina sofreu um desligamento
**limpo** 23 segundos depois. Nao foi panico nem falha de boot: `ACPI S5` e o
sinal que o hipervisor envia em `terminate-instances`. O no estava saudavel e
foi derrubado de fora.

**Segunda, o CloudTrail:**

```
23:43:48  RunInstances        AutoScaling   i-011082e0
23:43:55  TerminateInstances  sys7042595    i-011082e0
23:46:55  TerminateInstances  AutoScaling   i-011082e0
```

`sys7042595` nao e o Auto Scaling, nao e o EKS e nao e o usuario (que aparece
como `user5644817=...` quando rodou o `destruir.sh`). E um processo
automatizado da conta do AWS Academy que termina a instancia 7 segundos depois
do lancamento. O ASG relanca, ele mata de novo, e o ciclo se repete a cada
~2 minutos ate o EKS desistir.

**Nao ha correcao possivel no Terraform**: e politica da conta.

E o limite e de **instancias simultaneas na conta inteira**, somando todos os
labs - nao deste cluster. A listagem fechou a conta exatamente:

| | instancias |
|---|---|
| outro lab (`vm_0..3_fiap_vm_k8s`) | 4 |
| VMs de lab de sessoes anteriores, ainda ligadas | 2 |
| a VM de lab em uso | 1 |
| **fora do EKS** | **7** |
| nos do EKS (`t3.large`, sem tag Name) | 2 |
| **total** | **9** |

Nove e o limite do AWS Academy Learner Lab. Entao `7 + 2 nos = 9` cabe - e foi
o cluster que rodou por horas -, enquanto `7 + 3 = 10` estoura. Nao e falha de
criacao: dois nos ficam de pe, e o terceiro e morto repetidamente, de modo que
o node group nunca fica completo.

Isso explica o que mais incomodava na investigacao: por que o **mesmo codigo**
funcionou com 2 nos e falhou com 3. O que mudou nao foi o lab EKS, foi quanto
os outros labs ja ocupavam.

A correcao de verdade nao e escolher 2 ou 3, e sim **avisar antes**. O
`preparar.sh` ganhou uma checagem de orcamento na etapa 3: conta as instancias
em execucao, desconta as deste cluster, soma os nos que serao pedidos e aborta
em segundos se o total passar de `LIMITE_INSTANCIAS` (default 9), listando o
que esta ocupando o orcamento e sugerindo quantos nos ainda cabem.

E, ja que o script consulta o orcamento, ele passou a **escolher sozinho**:
pede `NODE_SIZE_PREFERIDO` nos (default 3) quando cabem, cai para o que couber
quando nao cabem, e so aborta quando nem `NODE_SIZE_MINIMO` (default 2) entra.
O numero escolhido vai ao terraform por `-var`, para nunca divergir do que foi
validado. Definir `node_desired_size` no `terraform.tfvars` ou
`NODE_DESIRED_SIZE` no ambiente desliga a escolha automatica.

Vale o contraste com a minha tentativa anterior: eu tinha "resolvido" fixando
o default em 2, o que funcionava mas jogava fora o terceiro no mesmo quando
havia espaco para ele - e fixar em 3 quebrava a aula quando nao havia. A
informacao para decidir ja estava na mao; faltava usa-la. O default do
`variables.tf` fica em 2 apenas para quem roda `terraform apply` direto.

### O que isso ensinou sobre o diagnostico

Cada uma das quatro hipoteses erradas tinha a mesma forma: eu lia um estado
intermediario e tratava como conclusao. O que finalmente funcionou foi parar
de inferir e capturar evidencia bruta - o console da maquina e o CloudTrail.
Ambos entraram no `diagnostico.sh`, com os veredictos ja interpretados:

- o modo `--vigiar` pega o console antes de o ASG destruir a instancia;
- `quem_matou()` consulta o CloudTrail e **classifica o autor**: Auto Scaling
  (reciclagem normal), EKS (desistiu), o proprio usuario, ou um principal
  estranho - caso em que avisa explicitamente que e conformidade da conta e
  nao problema do cluster.

Um diagnostico que so repete "ainda esperando" nao e diagnostico. O valor
esta em nomear o autor.

---

## Sobre os 15 minutos

A maior parte e irredutivel e nao esta no codigo: o control plane do EKS leva
~9 a 11 minutos e o managed node group ~3 a 5, e o node group **nao pode**
comecar antes de o cluster estar `ACTIVE`. O que foi possivel recuperar:

| Item | Ganho |
|---|---|
| `terraform plan` antes do `apply` em `preparar.sh` (trabalho jogado fora) | ~30-60s |
| `aws_lb` + 2 ENIs que ninguem usava | alguns minutos no `destroy`, e ~US$ 16/mes |
| esperas fixas no `awscli_eks_create.sh` (500s + 400s) trocadas por `aws eks wait` | ate ~4 min **naquele** caminho |
| verificacoes previas | evita perder 11 min para descobrir que falta o key pair |

Para reduzir de verdade, as opcoes sao arquiteturais (nao aplicadas, para nao
mudar o conteudo da aula):

- **EKS Auto Mode** ou **Fargate**: dispensa o node group, tira ~4 min do
  caminho, mas muda o que se ensina sobre nos;
- **`node_desired_size = 1`**: ~1 min menos e metade do custo de EC2, ao preco
  de nao demonstrar scheduling entre nos;
- **cluster de longa duracao** criado pelo professor, com os alunos recebendo
  acesso via `extra_admin_role_names`: o aluno nao espera nada. E o maior ganho
  possivel, se o objetivo da aula for usar o Kubernetes e nao provisiona-lo.

## O que nao foi alterado de proposito

- os defaults (nome `eksfiap`, `us-east-1`, 2 x `t3.medium`, SG aberto): o
  roteiro de aula continua valendo sem mudanca;
- `delete_vpc.sh`: codigo de terceiros, apenas passou a ser chamado na ordem
  certa;
- `bkp/`, `iam/bkp/` e `eksfiap_ajustar`: material historico. O
  `eksfiap_ajustar` usa a funcao `map()`, removida no Terraform 0.12+, e nao
  roda - fica como referencia.

## Como validei

- `terraform validate` e `terraform fmt -check` passam em `main.tf`,
  `variables.tf` e `outputs.tf` (provider AWS 5.100). **Nao houve `terraform
  plan`/`apply` contra a AWS**: este ambiente nao tem credenciais;
- `shellcheck -S warning` limpo em todos os scripts reescritos (as pendencias
  restantes estao no `delete_vpc.sh`, de terceiros);
- `bash -n` / `sh -n` em todos os scripts;
- `config_credenciais.sh` testado nos 4 caminhos (bloco completo, vazio,
  colagem incompleta, sem `[default]`);
- `preparar.sh` testado com `aws`/`terraform` simulados: ferramenta ausente,
  credencial invalida, role ausente, key pair ausente, cluster pre-existente e
  repasse de `-var`;
- `kubectl.sh` testado no modo `host` (caminho completo, abrindo o shell com o
  `kubectl` configurado) e nos guards de cluster inexistente e Docker parado;
- **nao testado**: o modo `docker` do `conectar.sh` e o build do
  `files/Dockerfile` - sem daemon Docker neste ambiente.

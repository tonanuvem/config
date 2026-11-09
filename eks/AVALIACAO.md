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

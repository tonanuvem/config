Pasta de trabalho dos scripts do lab EKS.

Conteudo versionado:

- `Dockerfile` - imagem `tonanuvem/kubectl-aws-cli` (AWS CLI v2 + kubectl),
  usada por `kubectl.sh` no modo docker.
- `credentials.example` - formato esperado pelo `config_credenciais.sh`.

Gerado em tempo de execucao e **nao versionado** (ver `.gitignore` na raiz):

- `credentials` - credenciais da AWS gravadas por `config_credenciais.sh`
  (permissao 600).
- `kube/config` - kubeconfig gerado por `kubectl.sh`, para nao mexer no
  `~/.kube/config` da maquina.

Para reconstruir a imagem, use o script (ele ja confere `aws` e `kubectl`
dentro da imagem depois do build):

```
sh ../build_imagem.sh
```

Isso gera a tag local `eks-lab/kubectl-aws-cli:local`, que o `kubectl.sh` passa
a preferir automaticamente. Para escolher a versao do `kubectl`:

```
KUBECTL_VERSION=v1.32.5 sh ../build_imagem.sh
```

Para reconstruir e **publicar** a imagem oficial do lab:

```
sh ../build_imagem.sh -t tonanuvem/kubectl-aws-cli
docker push tonanuvem/kubectl-aws-cli
```

Quem tem `aws` e `kubectl` na propria maquina (AWS CloudShell, por exemplo)
nao precisa da imagem: `sh conectar.sh` usa o modo `host` automaticamente.

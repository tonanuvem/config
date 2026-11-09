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

Para reconstruir e publicar a imagem:

```
docker build -t tonanuvem/kubectl-aws-cli ./files
docker run --rm --entrypoint /bin/sh tonanuvem/kubectl-aws-cli \
    -c 'aws --version && kubectl version --client'
docker push tonanuvem/kubectl-aws-cli
```

Quem tem `aws` e `kubectl` na propria maquina (AWS CloudShell, por exemplo)
nao precisa da imagem: `sh conectar.sh` usa o modo `host` automaticamente.

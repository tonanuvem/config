#!/bin/bash

# ============================================================
# VS CODE NO NAVEGADOR (vscode.dev) - VS Code Tunnel
#
# Uso pelo aluno, NA VM:
#
#   curl -fsSL https://raw.githubusercontent.com/tonanuvem/config/main/vscode.sh | bash
#
# ou "bash vscode.sh" (criado na VM pelo playbook utils), ou a opcao
# "VS Code no navegador" do menu fiaplab no CloudShell.
#
# Alternativa ao code-server em http://IP:8099 para redes que bloqueiam
# o IP da AWS: a propria VM abre uma conexao de SAIDA para o servico de
# tuneis da Microsoft, e o aluno abre
#
#   https://vscode.dev/tunnel/<nome>/home/ubuntu
#
# com o VS Code oficial rodando na VM (arquivos, terminal, docker).
# O endereco nao depende do IP: vale depois de suspender e religar.
#
# Etapas (cada uma so roda se faltar):
#   1. VS Code CLI ("code") em /usr/local/bin  (o playbook do
#      code-server ja instala; aqui e o reforco para VMs antigas)
#   2. nome do tunel, guardado em ~/.fiap_vscode_nome
#   3. login no GitHub (codigo em github.com/login/device)
#   4. servico do systemd (code-tunnel.service, de usuario) + linger,
#      para o tunel subir sozinho a cada boot, sem SSH aberto
#
# Subcomandos:
#   (nenhum)   ativa, ou so mostra o endereco se ja estiver ativo
#   status     mostra endereco e estado
#   link       imprime so o endereco (usado pelo menu do CloudShell)
#   nome       troca o nome do tunel
#   desativar  remove o servico (o nome continua guardado)
#
# Precedencia do nome: VSCODE_NOME do ambiente > ~/.fiap_vscode_nome >
# perguntar (sugerindo o nome do DNS, ~/.fiap_dns_nome).
# ============================================================

set -u

ORIGEM="https://raw.githubusercontent.com/tonanuvem/config/main/vscode.sh"
CLI_URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64"
ARQ_NOME="$HOME/.fiap_vscode_nome"
ARQ_DNS="$HOME/.fiap_dns_nome"
UNIDADE="code-tunnel.service"

# Limite do proprio VS Code (MAX_TUNNEL_NAME_LENGTH = 20).
PREFIXO="fiaplab-"
MAX_NOME=20

if [ -t 1 ]; then
    VERDE='\033[0;32m'; VERMELHO='\033[0;31m'; AMARELO='\033[1;33m'
    NEGRITO='\033[1m'; URL='\033[1;96m'; FIM='\033[0m'
else
    VERDE=''; VERMELHO=''; AMARELO=''; NEGRITO=''; URL=''; FIM=''
fi

erro()  { echo -e "${VERMELHO}  ❌ $*${FIM}" >&2; }
aviso() { echo -e "${AMARELO}  ⚠️  $*${FIM}"; }
ok()    { echo -e "${VERDE}  ✅ $*${FIM}"; }

# Com "curl | bash" a entrada padrao e o proprio script: todo read e
# todo comando que pode perguntar algo leem do /dev/tty, senao
# consumiriam o resto do codigo.
tem_tty() { [ -r /dev/tty ] && [ -w /dev/tty ] && { : </dev/tty; } 2>/dev/null; }

nome_salvo() { [ -s "$ARQ_NOME" ] && tr -d '[:space:]' < "$ARQ_NOME"; }

endereco() { echo "https://vscode.dev/tunnel/$1$HOME"; }

# "Maria José da Silva" -> "fiaplab-mariasilva": primeiro e ultimo
# nome, minusculas, sem acento, so letras e numeros, cortado no limite
# do VS Code. Um nome so ("profandre", o do DNS) fica como esta.
# Tira acentos sem depender do locale: o iconv //TRANSLIT vira "?" no
# locale C, que e o que um SSH sem LANG recebe. A troca do bash compara
# bytes, entao funciona em qualquer locale.
sem_acento() {
    local s="$1" par
    for par in á:a à:a â:a ã:a ä:a é:e è:e ê:e ë:e í:i ì:i î:i ï:i \
               ó:o ò:o ô:o õ:o ö:o ú:u ù:u û:u ü:u ç:c ñ:n \
               Á:a À:a Â:a Ã:a Ä:a É:e È:e Ê:e Ë:e Í:i Ì:i Î:i Ï:i \
               Ó:o Ò:o Ô:o Õ:o Ö:o Ú:u Ù:u Û:u Ü:u Ç:c Ñ:n; do
        s=${s//${par%%:*}/${par##*:}}
    done
    printf '%s' "$s"
}

gerar_nome() {
    local base primeiro ultimo
    base=$(sem_acento "$1")
    base=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' ' ')
    base=${base#"$PREFIXO"}
    primeiro=$(printf '%s' "$base" | awk '{print $1}')
    ultimo=$(printf '%s' "$base" | awk 'NF > 1 {print $NF}')
    base=$(printf '%s%s' "$primeiro" "$ultimo" | tr -cd 'a-z0-9-')
    base=${base#-}
    [ -n "$base" ] || return 1
    printf '%s' "${PREFIXO}${base}" | cut -c1-"$MAX_NOME" | sed 's/-*$//'
}

# ------------------------------------------------------------
# 1. VS Code CLI
#
# O code-server NAO traz um comando "code"; se existir um, conferimos
# que e o CLI do VS Code (tem o subcomando tunnel).
# ------------------------------------------------------------

cli_ok() { command -v code >/dev/null 2>&1 && code tunnel --help >/dev/null 2>&1; }

instalar_cli() {
    cli_ok && return 0

    echo "  Instalando o VS Code CLI..."
    local tmp destino
    tmp=$(mktemp -d) || return 1
    if ! curl -fsSL --max-time 120 "$CLI_URL" -o "$tmp/cli.tar.gz" \
        || ! tar -xzf "$tmp/cli.tar.gz" -C "$tmp" code; then
        rm -rf "$tmp"
        erro "Não foi possível baixar o VS Code CLI."
        echo "     Verifique a internet da VM e rode de novo."
        return 1
    fi

    if sudo -n true 2>/dev/null; then
        sudo install -m 0755 "$tmp/code" /usr/local/bin/code
        destino=/usr/local/bin/code
    else
        mkdir -p "$HOME/.local/bin"
        install -m 0755 "$tmp/code" "$HOME/.local/bin/code"
        destino="$HOME/.local/bin/code"
        export PATH="$HOME/.local/bin:$PATH"
    fi
    rm -rf "$tmp"

    cli_ok || { erro "O VS Code CLI foi copiado para $destino, mas não executa."; return 1; }
    ok "VS Code CLI instalado em $destino"
}

# ------------------------------------------------------------
# Estado do tunel
#
# "code tunnel status" imprime um JSON:
#   {"tunnel":null,"service_installed":false}       nada rodando
#   {"tunnel":{... "tunnel":"Connected" ...},...}    no ar
# ------------------------------------------------------------

status_json()       { code tunnel status 2>/dev/null; }
servico_instalado() { status_json | grep -q '"service_installed":true'; }
conectado()         { status_json | grep -q '"Connected"'; }
logado()            { code tunnel user show >/dev/null 2>&1; }

mostrar_endereco() {
    echo ""
    echo "============================================================"
    echo ""
    echo "   Abra no navegador (entre com a mesma conta do GitHub):"
    echo ""
    echo -e "      ${URL}$(endereco "$1")${FIM}"
    echo ""
    echo "============================================================"
    echo ""
}

cmd_link() {
    local n
    n=$(nome_salvo) || return 1
    endereco "$n"
}

cmd_status() {
    local n
    if ! n=$(nome_salvo); then
        echo "  VS Code Tunnel: ainda não ativado nesta VM. Rode: bash vscode.sh"
        return 1
    fi
    if ! cli_ok; then
        echo "  VS Code Tunnel: $n (VS Code CLI não instalado)"
        return 1
    fi
    if conectado; then
        echo "  VS Code Tunnel: $n (no ar)"
    elif servico_instalado; then
        echo "  VS Code Tunnel: $n (serviço instalado, ainda conectando)"
    else
        echo "  VS Code Tunnel: $n (desativado)"
    fi
    echo "  Endereço      : $(endereco "$n")"
}

# ------------------------------------------------------------
# 2. Nome
# ------------------------------------------------------------

escolher_nome() {
    local sugestao="" resp n dns

    if [ -n "${VSCODE_NOME:-}" ]; then
        gerar_nome "$VSCODE_NOME" && return 0
        erro "VSCODE_NOME inválido: use letras e números."
        return 1
    fi

    if [ "${1:-}" != "trocar" ] && n=$(nome_salvo); then
        printf '%s' "$n"
        return 0
    fi

    if [ -s "$ARQ_DNS" ] && dns=$(tr -d '[:space:]' < "$ARQ_DNS") && [ -n "$dns" ]; then
        sugestao=$(gerar_nome "$dns")
    fi

    if ! tem_tty; then
        erro "Sem terminal para perguntar o nome."
        echo "     Rode com:  curl -fsSL $ORIGEM | VSCODE_NOME=nomesobrenome bash" >&2
        return 1
    fi

    {
        echo ""
        echo "  O túnel precisa de um nome único, que vira o seu endereço:"
        echo "     https://vscode.dev/tunnel/${PREFIXO}NOMESOBRENOME"
        echo ""
    } >/dev/tty

    while true; do
        if [ -n "$sugestao" ]; then
            read -rp "  Seu nome e sobrenome [Enter usa $sugestao]: " resp </dev/tty || return 1
            [ -z "$resp" ] && { printf '%s' "$sugestao"; return 0; }
        else
            read -rp "  Seu nome e sobrenome: " resp </dev/tty || return 1
        fi
        if n=$(gerar_nome "$resp"); then
            printf '%s' "$n"
            return 0
        fi
        echo "  Use letras e números." >/dev/tty
    done
}

# ------------------------------------------------------------
# 3. Login no GitHub
#
# "code tunnel user login" mostra um codigo, espera o aluno digitar em
# github.com/login/device e TERMINA -- nao fica preso ao terminal. O
# login fica gravado em ~/.vscode/cli e o servico reaproveita.
# ------------------------------------------------------------

garantir_login() {
    logado && return 0

    if ! tem_tty; then
        erro "Falta o login no GitHub, e ele precisa de um terminal."
        echo "     Pelo CloudShell, use a opção do menu; ou rode na VM: bash vscode.sh" >&2
        return 1
    fi

    echo ""
    echo "------------------------------------------------------------"
    echo -e "  ${NEGRITO}Login no GitHub${FIM} (só na primeira vez nesta VM)"
    echo ""
    echo "  1. Abra no navegador:  https://github.com/login/device"
    echo "  2. Entre com a sua conta do GitHub"
    echo "  3. Digite o código que aparece abaixo e autorize"
    echo ""
    echo "  Use a mesma conta depois, para abrir o vscode.dev."
    echo "------------------------------------------------------------"
    echo ""

    code tunnel user login --provider github </dev/tty || {
        erro "O login não foi concluído. Rode de novo para tentar outra vez."
        return 1
    }
    logado || { erro "O login não ficou gravado."; return 1; }
    ok "Login concluído."
}

# ------------------------------------------------------------
# 4. Servico + linger
# ------------------------------------------------------------

garantir_linger() {
    # Sem linger, o systemd de usuario morre quando a ultima sessao SSH
    # fecha e nao sobe no boot -- o tunel so viveria com alguem logado.
    if loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes'; then
        return 0
    fi
    if sudo -n loginctl enable-linger "$USER" 2>/dev/null; then
        return 0
    fi
    aviso "Não consegui ativar o linger. O túnel pode cair ao fechar o SSH."
    echo "     Rode:  sudo loginctl enable-linger $USER"
}

instalar_servico() {
    local nome="$1" atual

    atual=$(nome_salvo || true)

    # Ja no ar com o mesmo nome: nada a fazer.
    if [ "$atual" = "$nome" ] && servico_instalado && conectado; then
        return 0
    fi

    # Um "code tunnel" rodando em primeiro plano (teste manual) ocupa o
    # lugar do servico: encerra antes de instalar.
    if ! servico_instalado && status_json | grep -q '"tunnel":{'; then
        code tunnel kill >/dev/null 2>&1 || true
    fi

    echo "  Registrando o túnel $nome..."
    if ! code tunnel service install --accept-server-license-terms --name "$nome" </dev/null; then
        erro "Falha ao instalar o serviço do túnel."
        echo "     Detalhes:  code tunnel service log"
        return 1
    fi

    # Troca de nome com o servico ja rodando: reinicia para valer.
    systemctl --user restart "$UNIDADE" 2>/dev/null || true

    printf '%s\n' "$nome" > "$ARQ_NOME"
    garantir_linger
}

esperar_conexao() {
    local i
    printf '  Aguardando o túnel conectar'
    for i in $(seq 1 30); do
        if conectado; then
            echo ""
            return 0
        fi
        printf '.'
        sleep 2
    done
    echo ""
    aviso "O túnel ainda não respondeu. Ele continua tentando sozinho."
    echo "     Acompanhe com:  code tunnel service log"
    return 1
}

cmd_ativar() {
    local nome

    echo ""
    echo "============================================================"
    echo "  VS CODE NO NAVEGADOR (vscode.dev)"
    echo "============================================================"
    echo ""

    instalar_cli || return 1
    nome=$(escolher_nome "${1:-}") || return 1
    echo "  Nome do túnel    : $nome"

    garantir_login || return 1
    instalar_servico "$nome" || return 1
    esperar_conexao && ok "Túnel no ar."

    mostrar_endereco "$nome"
    echo "  O túnel sobe sozinho quando a VM liga; o endereço não muda."
    echo "  Ver de novo:  bash vscode.sh status"
    echo ""
}

cmd_desativar() {
    cli_ok || { echo "  VS Code CLI não instalado: nada a desativar."; return 0; }
    if servico_instalado; then
        code tunnel service uninstall
        ok "Túnel desativado. Para ativar de novo: bash vscode.sh"
    else
        echo "  O serviço do túnel não está instalado."
    fi
}

case "${1:-}" in
    "")        cmd_ativar ;;
    status)    cmd_status ;;
    link)      cmd_link ;;
    nome)      cmd_ativar trocar ;;
    desativar) cmd_desativar ;;
    *)
        echo "Uso: bash vscode.sh [status|link|nome|desativar]"
        exit 1
        ;;
esac

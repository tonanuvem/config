#!/bin/bash

# ============================================================
# REGISTRO DNS DO LABORATORIO
#
# Uso pelo aluno:
#
#   curl -s https://raw.githubusercontent.com/tonanuvem/config/main/dns.sh | bash
#
# Registra o IP publico desta VM sob um nome escolhido pelo aluno,
# dentro da zona da turma. O IP da VM muda a cada aula, entao rodar de
# novo com o mesmo nome apenas ATUALIZA o endereco.
#
# Posse do nome: a senha da API e a mesma para a turma inteira, entao
# ela nao distingue um aluno de outro. Na primeira execucao este script
# gera um token aleatorio e o guarda em ~/.fiap_dns_token; a API grava
# o hash dele junto do registro e passa a exigi-lo para alterar ou
# apagar. Resultado: o aluno re-registra o proprio nome quantas vezes
# quiser, e ninguem sobrescreve o nome de outro.
#
# Perdeu a VM e com ela o token? O nome fica preso. Peca ao instrutor
# para apagar o registro na tabela do DynamoDB -- o token nao pode ser
# recuperado, so o registro removido.
#
# NOTA SOBRE A SENHA: a senha abaixo e de TURMA, nao um segredo. Ela
# ja vai embutida no bundle do frontend, que e publico. Quem protege o
# nome do aluno e o token acima, nao ela.
# ============================================================

set -u

API_URL="${DNS_API_URL:-https://api.aluno.lab.tonanuvem.com}"
SENHA_API="${DNS_API_KEY:-aluno}"
ZONA="${DNS_ZONA:-aluno.lab.tonanuvem.com}"

ARQ_TOKEN="$HOME/.fiap_dns_token"

VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NEGRITO='\033[1m'
FIM='\033[0m'

echo ""
echo "============================================================"
echo "  REGISTRO DNS - ${ZONA}"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# Pre-requisitos
# ------------------------------------------------------------

for CMD in curl; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        echo -e "${VERMELHO}Comando necessário ausente: $CMD${FIM}"
        exit 1
    fi
done

# ------------------------------------------------------------
# IP publico desta VM
# ------------------------------------------------------------

IP=$(curl -s --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')

if ! [[ "$IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    echo -e "${VERMELHO}Não foi possível descobrir o IP público desta máquina.${FIM}"
    echo "Verifique a conexão e tente de novo."
    exit 1
fi

echo "  IP desta máquina : $IP"

# ------------------------------------------------------------
# Token de posse
#
# Gerado uma vez e reutilizado. Sem ele o aluno nao conseguiria
# atualizar o proprio registro na aula seguinte.
# ------------------------------------------------------------

if [ -s "$ARQ_TOKEN" ]; then
    TOKEN=$(tr -d '[:space:]' < "$ARQ_TOKEN")
    echo "  Token            : reaproveitado de ~/.fiap_dns_token"
else
    # openssl nem sempre esta instalado; /dev/urandom esta sempre.
    if command -v openssl >/dev/null 2>&1; then
        TOKEN=$(openssl rand -hex 16)
    else
        TOKEN=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi

    ( umask 077; printf '%s\n' "$TOKEN" > "$ARQ_TOKEN" )
    echo "  Token            : novo, salvo em ~/.fiap_dns_token"
fi

# ------------------------------------------------------------
# Nome escolhido pelo aluno
#
# O </dev/tty e obrigatorio: com "curl | bash" a entrada padrao e o
# proprio script, entao um "read" comum leria o codigo em vez de
# esperar o aluno digitar.
# ------------------------------------------------------------

echo ""
echo "Escolha um nome curto (letras minúsculas, números e hífen)."
echo "Ele vira: SEUNOME.${ZONA}"
echo ""

read -rp "Nome: " NOME </dev/tty

NOME=$(printf '%s' "$NOME" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

if [ -z "$NOME" ]; then
    echo -e "${VERMELHO}Nenhum nome informado.${FIM}"
    exit 1
fi

echo ""
echo "  Registrando ${NEGRITO}${NOME}.${ZONA}${FIM} -> $IP"
echo ""

# ------------------------------------------------------------
# Chamada a API
#
# Tenta criar. Se o nome ja existe (409), tenta atualizar com o token:
#   - token confere  -> e o proprio aluno, o IP e atualizado
#   - token nao bate -> 403, o nome e de outra pessoa
# ------------------------------------------------------------

chamar() {
    # Imprime "<corpo>\n<status>" para separarmos depois.
    #
    # O corpo vai num array em vez de interpolado na linha: um JSON
    # solto e sem aspas seria quebrado em palavras pelo shell no dia em
    # que ganhasse um espaco.
    local METODO="$1" ROTA="$2" CORPO_REQ="${3:-}"
    local -a ARGS=()

    [ -n "$CORPO_REQ" ] && ARGS=(-d "$CORPO_REQ")

    curl -s -w '\n%{http_code}' --max-time 25 \
        -X "$METODO" "$API_URL$ROTA" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $SENHA_API" \
        -H "x-dns-token: $TOKEN" \
        "${ARGS[@]}"
}

RESP=$(chamar POST "/registros" \
    "{\"alias\":\"$NOME\",\"endereco_ip\":\"$IP\",\"token\":\"$TOKEN\"}")

STATUS=$(printf '%s' "$RESP" | tail -n1)
CORPO=$(printf '%s' "$RESP" | sed '$d')

if [ "$STATUS" = "409" ]; then
    echo "  O nome já existe. Verificando se é seu..."
    echo ""

    RESP=$(chamar PUT "/registros/$NOME" \
        "{\"endereco_ip\":\"$IP\",\"token\":\"$TOKEN\"}")

    STATUS=$(printf '%s' "$RESP" | tail -n1)
    CORPO=$(printf '%s' "$RESP" | sed '$d')
fi

# ------------------------------------------------------------
# Resultado
# ------------------------------------------------------------

case "$STATUS" in

    200|201)
        echo -e "${VERDE}  ✅ Registro criado/atualizado com sucesso!${FIM}"
        echo ""
        echo "============================================================"
        echo ""
        echo -e "   ${NEGRITO}http://${NOME}.${ZONA}${FIM}"
        echo ""
        echo "============================================================"
        echo ""
        echo "  O DNS pode levar até 1 minuto para propagar."
        echo "  Conferir:  dig +short ${NOME}.${ZONA}"
        echo ""
        echo "  Na próxima aula, rode este script de novo com o MESMO"
        echo "  nome: o IP muda, o nome continua seu."
        echo ""
        ;;

    403)
        echo -e "${VERMELHO}  ❌ Este nome pertence a outra pessoa.${FIM}"
        echo ""
        echo "  Escolha outro nome e rode o script de novo."
        echo ""
        echo "  Se o nome era seu e você perdeu a VM (e com ela o"
        echo "  ~/.fiap_dns_token), peça ao instrutor para apagar o"
        echo "  registro — o token não tem como ser recuperado."
        echo ""
        exit 1
        ;;

    400)
        echo -e "${VERMELHO}  ❌ Nome ou IP recusado pela API:${FIM}"
        echo ""
        echo "     $CORPO"
        echo ""
        exit 1
        ;;

    401)
        echo -e "${VERMELHO}  ❌ Senha da API inválida.${FIM}"
        echo ""
        echo "  O script está configurado para: $API_URL"
        echo "  Confirme com o instrutor a senha e a URL da turma."
        echo ""
        exit 1
        ;;

    000|"")
        echo -e "${VERMELHO}  ❌ Não foi possível falar com a API.${FIM}"
        echo ""
        echo "  Verifique a conexão desta máquina com a internet."
        echo "  URL: $API_URL"
        echo ""
        exit 1
        ;;

    *)
        echo -e "${AMARELO}  ⚠️  Resposta inesperada da API (HTTP $STATUS):${FIM}"
        echo ""
        echo "     $CORPO"
        echo ""
        exit 1
        ;;
esac

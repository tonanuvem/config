echo ""
echo ""
echo "Digite seu nome para ser usado no DNS: " 
read NOME_DNS </dev/tty

ip=$(curl -s checkip.amazonaws.com)
hostname="$NOME_DNS.fiapaws.tonanuvem.com."
secret="fiaplab"
texto="${ip}${hostname}${secret}"

echo "Texto para ser calculado o Hash = ${texto}:"

hash=$(python3 -c "import hashlib; print(hashlib.sha256('$texto'.encode('utf8')).hexdigest())")
echo $hash

echo "Parametros:"
echo "  IP       = ${ip}"
echo "  HOSTNAME = ${hostname}"
echo "  SECRET   = ${secret}"

echo ""
echo "Atualizando o DNS:"

curl -X POST "https://dns.fiapaws.tonanuvem.com/labdns" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"internal_ip\": \"$ip\",\"set_hostname\": \"$hostname\",\"validation_hash\": \"$hash\"}"
echo ""
echo ""
echo "Acessar:"
echo "http://$NOME_DNS.fiapaws.tonanuvem.com"
echo ""
echo ""

ip=$(curl -s checkip.amazonaws.com)
hostname="homologacao.fiapaws.tonanuvem.com."
secret="fiaplab"
texto="${ip}${hostname}${secret}"

echo "Texto para ser calculado o Hash = ${texto}:"

hash=$(python -c "import hashlib; print(hashlib.sha256('$texto'.encode('utf8')).hexdigest())")
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

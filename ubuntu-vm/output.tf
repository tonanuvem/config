# aws_instance.web tem count, entao .*.public_ip ja e uma lista.
# Os colchetes extras que existiam aqui embrulhavam essa lista em
# outra, produzindo [["ip"]] -- e era por isso que todo consumidor
# precisava de um jq '.[][]'.
output "dns_externo" {
  value = aws_instance.web[*].public_dns
}

output "ip_externo" {
  value = aws_instance.web[*].public_ip
}

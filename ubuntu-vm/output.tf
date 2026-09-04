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

# Compare os dois: se divergirem, o pin em variable.tf ficou para tras.
# Vale revisitar entre semestres -- medido em 2026-09-04, uma imagem do
# dia no lugar de uma de meses atras derrubou o lab de 223s para 198s,
# porque os pacotes base ja vem atualizados e o apt baixa menos.
output "ami_em_uso" {
  value = local.ami_escolhida
}

output "ami_mais_recente_disponivel" {
  value = "${data.aws_ami.ubuntu_recente.id} (${data.aws_ami.ubuntu_recente.creation_date})"
}

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
# Vale atualizar entre semestres -- imagem mais fresca encurta a janela
# em que o unattended-upgrades do boot segura o lock do apt.
output "ami_em_uso" {
  value = local.ami_escolhida
}

output "ami_mais_recente_disponivel" {
  value = "${data.aws_ami.ubuntu_recente.id} (${data.aws_ami.ubuntu_recente.creation_date})"
}

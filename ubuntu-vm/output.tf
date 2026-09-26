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

# O proprio output ensina o caminho, para nao ser preciso lembrar o nome
# da variavel nem editar arquivo so para experimentar uma imagem nova.
# A flag usar_ami_mais_recente e um bool comum do Terraform, entao aceita
# a forma TF_VAR_<nome> como variavel de ambiente.
output "ami_status" {
  value = (
    local.ami_escolhida == data.aws_ami.ubuntu_recente.id
    ? "pin em dia com a imagem mais recente da Canonical"
    : "pin DESATUALIZADO. Para testar a nova sem editar arquivo: export TF_VAR_usar_ami_mais_recente=true && terraform apply | Aprovada, promova o ID em variable.tf e rode: unset TF_VAR_usar_ami_mais_recente"
  )
}

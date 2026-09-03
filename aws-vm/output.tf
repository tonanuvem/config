# Mesma correcao aplicada em ubuntu-vm/output.tf: os colchetes
# extras aninhavam a lista sem necessidade. Nenhum script le estes
# outputs hoje.
output "dns_externo" {
  value = aws_instance.web[*].public_dns
}

output "ip_externo" {
  value = aws_instance.web[*].public_ip
  #value = "${aws_elb.web.dns_name}"
}

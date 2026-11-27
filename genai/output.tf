output "dns_externo" {
  value = ["${aws_instance.web.*.public_dns}"]
}

output "ip_externo" {
  value = ["${aws_instance.web.*.public_ip}"]
}

output "ip_interno" {
  value = ["${aws_instance.web.*.private_ip}"]
}

# Conferir que caiu tudo na mesma AZ, e qual e ela -- importa para decidir
# onde o no de GPU (g6f.large) pode entrar.
output "zona" {
  value = aws_subnet.default.availability_zone
}

output "tipo_instancia" {
  value = var.instance_type
}

# 1. Gera uma nova chave privada RSA dinamicamente
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2. Registra a chave PÚBLICA na AWS para a EC2 usar no boot
resource "aws_key_pair" "generated_key" {
  key_name   = "chave-fiaplab-vm" # Nome da Key Pair na AWS
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# 3. Salva a chave PRIVADA no diretório ~/.ssh do CloudShell
resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "$HOME/enviroment/chave-fiaplab-vm.pem" # Salva no $HOME/.ssh/
  file_permission = "0600" # Permissão estrita necessária para o SSH/Ansible
}

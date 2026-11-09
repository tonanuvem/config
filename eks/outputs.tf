# =============================================================================
# Outputs
#
# A versao anterior exportava um kubeconfig e um ConfigMap aws-auth que nao
# funcionavam mais:
#  * o kubeconfig usava "aws-iam-authenticator" com a apiVersion
#    client.authentication.k8s.io/v1alpha1, removida no Kubernetes 1.24+;
#  * o aws-auth tinha "rolearn: arn:aws:iam::*:role/..." (curinga nao e valido
#    em um ARN de role) e hoje e desnecessario, pois o cluster usa EKS Access
#    Entries (ver access_config em main.tf).
#
# O caminho suportado para gerar o kubeconfig e o comando abaixo, que tambem e
# o que os scripts kubectl.sh / cloud9_kubectl.sh executam.
# =============================================================================

output "aws_account_id" {
  description = "Conta AWS onde o cluster foi criado."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Regiao do cluster."
  value       = var.aws_region
}

output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.eksfiap.name
}

output "cluster_version" {
  description = "Versao do Kubernetes em execucao no control plane."
  value       = aws_eks_cluster.eksfiap.version
}

output "cluster_endpoint" {
  description = "Endpoint do API server."
  value       = aws_eks_cluster.eksfiap.endpoint
}

output "cluster_security_group_id" {
  description = <<-EOT
    Security group gerenciado pelo EKS e aplicado aos nos. E nele que se libera
    o acesso externo a Services do tipo NodePort.
  EOT
  value       = aws_eks_cluster.eksfiap.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  description = "Nome do managed node group."
  value       = aws_eks_node_group.demo.node_group_name
}

output "vpc_id" {
  description = "VPC do lab (usada por destruir.sh)."
  value       = aws_vpc.demo.id
}

output "subnet_ids" {
  description = "Subnets publicas do cluster."
  value       = aws_subnet.demo[*].id
}

output "kubeconfig_command" {
  description = "Comando para configurar o kubectl nesta maquina."
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.eksfiap.name}"
}

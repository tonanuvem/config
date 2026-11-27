# ATENCAO: antes de destruir, conferir se os modelos em /models do no 0 ja
# estao no S3. O EBS vai junto (delete_on_termination), e rebaixar 63 GB de
# GGUF custa tempo de sessao.
terraform destroy -auto-approve

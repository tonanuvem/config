terraform {
  backend "s3" {
    # bucket       = "BUCKET_NAME" # O bucket será injetado dinamicamente no init com comando : terraform init -backend-config="bucket=tfstate-cloudshell-$(aws sts get-caller-identity --query Account --output text)"
    bucket         = "tfstate-cloudshell"
    key            = "ubuntu-vm/terraform.tfstate" # Apenas altere o caminho para cada subpasta
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    use_lockfile   = true
    encrypt        = true
  }
}

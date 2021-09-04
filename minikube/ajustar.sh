terraform output ip_externo > hosts
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=minikube" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem


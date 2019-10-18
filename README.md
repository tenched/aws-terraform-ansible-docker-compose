# aws-terraform-ansible-docker-compose

This repository sets up the following infrastructure on AWS:

- S3 bucket (for remote Terraform state)
- DynamoDB table (for locking remote Terraform state)
- VPC
- 2 subnets
- internet gateway
- routing table
- 4 security groups
- ALB
- 2 listeners
- self-signed SSL certificate
- target group
- private Route53 hosted zone
- alias pointing to ALB
- ssh key pair
- launch template
- autoscaling group
- 2 EC2 instances
- ECR repository
- within the instances:
    - installs docker-ce
    - installs docker-compose
    - tags and pushes standard nginx image to ECR repository
    - runs nginx image from ECR repository using docker-compose
    - gets response from ALB available at http[s]://my-nginx.internal from within internal network

Pre-requisites

- Install Terraform 0.12.9+ https://www.terraform.io/downloads.html
- Install Ansible 2.8.5+ https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
- AWS
    - AWS IAM: create a user with programmatic access and "AdministratorAccess" policy attached https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
    - Install AWS CLI https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html
    - Configure AWS CLI with 'aws configure', make sure to supply AWS Access Key ID, AWS Secret Access Key and region "eu-central-1" https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
- Ssh keypair located at ~/.ssh/id_rsa, ~/.ssh/id_rsa.pub
- Install jq JSON processor 'sudo apt install jq'

How to use

- Generate self-signed key and certificate pair and put them to terraform/files folder
    - 'mkdir -p terraform/files && openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout terraform/files/nginx-selfsigned.key -out terraform/files/nginx-selfsigned.crt' (Filed issue on Ubuntu 18.04 https://github.com/openssl/openssl/issues/7754#issuecomment-541307674)

- Run Terraform
    - 'cd terraform'
    - 'terraform init'
    - 'terraform plan'
    - 'terraform apply'
    - (Optional). To use remote Terraform state (with locking) uncomment backend section inside terraform section in main.tf, change "bucket" and "region" values and run 'terraform init' again

- Generate Ansible inventory file
    - 'cd ../ansible'
    - './ansible-inventory.sh > ./hosts'

- Run Ansible
    - './ansible-run.sh'

- Destroy resources
    - 'cd ../terraform'
    - 'terraform destroy'
    - Delete S3 bucket manually from AWS console

Compatibility

- Verified on Ubuntu 18.04 LTS
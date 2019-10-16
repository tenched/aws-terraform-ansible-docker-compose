variable "aws_region" {
    default = "eu-central-1"
}

variable "vpc_cidr" {
    default = "10.0.0.0/16"
}

variable "availability_zones" {
  type = "list"
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "self-signed-cert-file" {
  default = "files/nginx-selfsigned.crt"
}

variable "self-signed-cert-key-file" {
  default = "files/nginx-selfsigned.key"
}

variable "domain_name" {
  default = "my-nginx.internal"
}

variable "public_ssh_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "image_id" {
  # Ubuntu Server 18.04 LTS (HVM), SSD Volume Type, 64-bit x86 - Canonical (free tier eligible)
  default = "ami-0cc0a36f626a4fdf5"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "min_size" {
  default = 1    
}

variable "max_size" {
  default = 2    
}

variable "desired_capacity" {
  default = 2
}

variable "docker_image" {
  default = "nginx"
}

variable "docker_image_version" {
  default = "latest"
}
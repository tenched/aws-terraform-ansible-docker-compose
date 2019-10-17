# Required Terraform version
terraform {
  required_version = ">= 0.12.9"

  # backend "s3" {
  #   encrypt = true
  #   # get bucket name from Terraform output
  #   bucket = "terraform-remote-state-storage20191017163916745500000001"
  #   dynamodb_table = "terraform-state-lock-dynamodb"
  #   region = "eu-central-1"
  #   key = "test/terraform.tfstate"
  # }
}

# Configure AWS Provider
provider "aws" {
    version = "~> 2.33"
    region = "${var.aws_region}"
}

# Create an S3 bucket to store the state file in
resource "aws_s3_bucket" "terraform-state-storage-s3" {
    # has to be unique globally
    bucket_prefix = "terraform-remote-state-storage"
    acl = "private"
 
     versioning {
      enabled = true
    }
 
    lifecycle {
      prevent_destroy = true
    }
 
    tags = {
      Name = "test S3 Remote Terraform State Storage"
    }
}

# Create a dynamodb table for locking the state file
resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name = "terraform-state-lock-dynamodb"
  hash_key = "LockID"
  read_capacity = 1
  write_capacity = 1
 
  attribute {
    name = "LockID"
    type = "S"
  }
 
  tags = {
    Name = "test DynamoDB Terraform State Lock Table"
  }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block            = "${var.vpc_cidr}"
  enable_dns_support    = "true"
  enable_dns_hostnames  = "true"

  tags = {
    Name = "test vpc"
  }
}

# Create subnets
resource "aws_subnet" "subnet" {
  count                     = "${length(var.availability_zones)}"
  availability_zone         = "${var.availability_zones[count.index]}"
  vpc_id                    = "${aws_vpc.main.id}"
  cidr_block                = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  map_public_ip_on_launch   = "true"


  tags = {
    Name = "test subnet-${count.index}"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "test igw"
  }
}

# Create routing table
resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "test rtb"
  }
}

# Associate routing table with subnets
resource "aws_route_table_association" "public" {
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${element(aws_subnet.subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtb.id}"
}

# Create security group for HTTP traffic
resource "aws_security_group" "http" {
  name        = "http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    # HTTP
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }   

  tags = {
    Name = "test http sg"
  }

}

# Create security group for HTTPS traffic
resource "aws_security_group" "https" {
  name        = "https"
  description = "Allow HTTPS inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    # TLS
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }  

  tags = {
    Name = "test https sg"
  }

}

# Create security group for SSH traffic
resource "aws_security_group" "ssh" {
  name        = "ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    # ssh
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }   

  tags = {
    Name = "test ssh sg"
  }

}

# Create security group for EGRESS traffic
resource "aws_security_group" "egress" {
  name        = "egress"
  description = "Allow all outbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }    

  tags = {
    Name = "test egress sg"
  }

}

# Create application load balancer
resource "aws_lb" "alb" {
  name               = "test-lb"
  internal           = "false"
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.http.id}", "${aws_security_group.https.id}", "${aws_security_group.egress.id}"]
  subnets            = "${aws_subnet.subnet.*.id}"
}

# Create target group
resource "aws_lb_target_group" "tg" {
  name     = "test-lb-tg"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"

  stickiness {
    type    = "lb_cookie"
    enabled = "false"
  }
}

# Create HTTP load balancer listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.tg.arn}"
  }
}

# Upload self-signed certificate to IAM
resource "aws_iam_server_certificate" "test_cert" {
  name_prefix      = "test-cert"
  certificate_body = "${file(var.self-signed-cert-file)}"
  private_key      = "${file(var.self-signed-cert-key-file)}"

  lifecycle {
    create_before_destroy = true
  }
}

# Create HTTPS load balancer listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${aws_iam_server_certificate.test_cert.arn}"  

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.tg.arn}"
  }
}

# Create private Route53 hosted zone
resource "aws_route53_zone" "private" {
  name = "${var.domain_name}"

  vpc {
    vpc_id = "${aws_vpc.main.id}"
  }
}

# Point APEX to load balancer's domain name
resource "aws_route53_record" "www" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "${var.domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_lb.alb.dns_name}"
    zone_id                = "${aws_lb.alb.zone_id}"
    evaluate_target_health = true
  }
}

# Create ssh key pair
resource "aws_key_pair" "ec2key" {
  key_name   = "test-ec2key"
  public_key = "${file(var.public_ssh_key)}"
}

# Create AWS launch template
resource "aws_launch_template" "launch_template" {
  name_prefix   = "test_launch_template"
  image_id      = "${var.image_id}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.ec2key.key_name}"

  network_interfaces {
    delete_on_termination       = "true"
    associate_public_ip_address = "true"
    security_groups             = ["${aws_security_group.http.id}", "${aws_security_group.ssh.id}", "${aws_security_group.egress.id}"]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Role = "test-nginx"
    }
  }

}

# Create autoscaling group
resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier   = "${aws_subnet.subnet.*.id}"
  target_group_arns     = ["${aws_lb_target_group.tg.arn}"]
  desired_capacity      = "${var.desired_capacity}"
  max_size              = "${var.max_size}"
  min_size              = "${var.min_size}"

  launch_template {
    id      = "${aws_launch_template.launch_template.id}"
    version = "$Latest"
  }

}

# Create AWS ECR repository
resource "aws_ecr_repository" "ecr_repo" {
  name = "${var.docker_image}"
}
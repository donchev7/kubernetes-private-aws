#
# K8s on AWS = Provider = AWS :)
#
provider "aws" {
  region = "eu-central-1"
}

#
# State will be saved on S3 so that multiple
# people can work on this code
#
terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "${var.name}"
    dynamodb_table = "${var.name}"
    region         = "eu-central-1"
    key            = "terraformState"
  }
}

#
# KeyPair for ssh
#
resource "aws_key_pair" "cluster" {
  key_name   = "${var.name}-ssh-key"
  public_key = "${file("ssh/cluster.pub")}"
}

#
# VPC to launch cluster in
#
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}"]
  }
}

#
# Where to place the cluster (which subnet)
#
data "aws_subnet" "selected" {
  filter {
    name   = "tag:Name"
    values = ["${var.subnet_name}"]
  }
}

#
# We choose Ubuntu as host for K8s
#
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#
# Master IP for remote kubectl configuration
#
resource "null_resource" "master_iplist" {
  triggers {
    always = "${uuid()}"
  }

  provisioner "local-exec" {
    command = "bash scripts/asgip.sh ${aws_autoscaling_group.master.name} > scripts/master_ips.txt"
  }
}

data "template_file" "masters" {
  depends_on = ["null_resource.master_iplist"]
  template   = "${file("${path.module}/scripts/master_ips.txt")}"
}

output "masters-ip" {
  value = "${replace(data.template_file.masters.rendered, "\n", "")}"
}

output "kubernetes_version" {
  value = "${var.kubernetes_version}"
}

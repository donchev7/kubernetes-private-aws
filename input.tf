#
# Input variables for the K8s cluster
#
variable "name" {
  default = "private-k8s-topo"
}
variable "proxy" {
  description = "Proxy server the cluster will run behind with port"
}

variable "master_instance_type" {
  default = "t2.medium"
}

variable "node_instance_type" {
  default = "t2.large"
}

variable "node_asg_min" {
  default = 1
}

variable "node_asg_max" {
  default = 10
}

variable "node_asg_desired" {
  default = 1
}

variable "kubernetes_version" {
  default = "1.9.3"
}

variable "kubernetes_dashboard_version" {
  default = "1.8.3"
}

variable "vpc_name" {
  description = "VPC to launch the cluster in"
}

variable "subnet_name" {
  description = "Subnet name where to launch the cluster in"
}

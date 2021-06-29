variable "region" {
    default = "us-east-1"
}

variable "master_instances" {
    default = 1
}

variable "instance_type" {
    default = "t2.medium"
}

variable "iam_instance_profile_id" {
    default = ""
}

variable "subnet_ids" {
    default = []
}

variable "azs" {
    default = []
}

variable "security_group_ids" {
    type = list
    default = []
}

variable "key_name" {
    default = ""
}

variable "cluster_name" {
    default = "kube-31B"
}

variable "vpc_id" {
    default = ""
}

variable "ssh_private_key" {
    default = ""
}

variable "s3_bucket" {
  default = ""
}

variable "ansible_bucket_name" {
    default = "kube-31"
}

variable "deployment_artifacts" {
    default = "ansible"
}

variable "kubernetes_version" {
    default = "1.21.2"
}

variable "kubeconfig_dir" {
    default = "~/.kube/"
}
varibale "etcd_instances" {
    default = 2
}

variable "subnet_ids" {
    default = []
}

variable "azs" {
    default = []
}

variable  "vpc_security_group_id" {
    default = []
}

variable "key_name" {
    default = ""
}

variable "instance_type" {
    default = "t2.medium"
}

variable "cluster_name" {
    default = "kube-31B"
}

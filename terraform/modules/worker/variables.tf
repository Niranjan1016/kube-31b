variable "cluster_name" {
    default = ""
}

variable "region" {
    default = "us-east-1"
}

variable "vpc_id" {
     default = ""
}

variable "worker_instance_type" {
    default = "t2.medium"
}

variable "key_name" {
    default = ""
}

variable "ssh_private_key" {
    default = ""
}

variable "instance_profile" {
    default = ""
}

variable "security_group_ids" {
    default = []
}

variable "min_worker_count" {
    default = 1
}

variable "max_worker_count" {
    default = 3
}

variable "worker_subnet_ids" {
    default = []
}

variable "bucket_name" {
    default = "k8learning"
}

variable "deployment_artifacts" {
     default = "ansible"
}

variable "master_alb_dns" {
    default = ""
}
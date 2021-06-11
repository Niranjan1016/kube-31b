variable "region" {
  description = "Region where Cloud Formation is created"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the AWS Kubernetes cluster - will be used to name all created resources"
  default = "kube-31B"
}

variable "ssh_public_key" {
  description = "Path to the pulic part of SSH key which should be used for the instance"
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_file" {
  description = "Path to the pulic part of SSH key which should be used for the instance"
  default     = "‪~/.ssh/id_rsa"
}

variable "cidr_block" {
  description = "CIDR block"
  default = "172.21.0.0/16"
}

variable "subnet_mask" {
    default = 4
}

variable "availablity_zones" {
    type = list(string)
    default = ["us-east-1a", "us-east-1b", "us-east-1c"]

}

variable "etcd_backup_keys" {
 default = 1
}

variable "userdata_s3_bucket" {  
  default = "kube-31"
}

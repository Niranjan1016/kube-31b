#ami
#ec2
#alb
#tg
#listener

module "ami" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami"
  region = "${var.region}"
  distribution = "xenial"
  virttype = "hvm"
  storagetype = "ebs-ssd"
}

resource "aws_instance" "etcd"{
    count = var.etcd_instances
    ami = module.ami.ami_id
    instance_type = var.instance_type
    subnet_id = element(var.subnet_ids, count.index)
    associate_public_ip_address = true
    availability_zone = element(var.azs, count.index)
    vpc_security_group_ids = var.vpc_security_group_id
    key_name = var.key_name
    tags = {

        Name = "etcd"
        ansible_managed = "yes"
        kubernetes_role = "etcd"
        terraform_module = "etcd"
        format("kubernetes.io/cluster/%v", var.cluster_name) = "owned"

    }
}
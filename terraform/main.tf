data "aws_caller_identity" "current" {}

provider "aws" {
    region = var.region
}

resource "aws_key_pair" "kubernetes" {
    key_name = var.cluster_name
    public_key = file(var.ssh_public_key)
}

resource "aws_vpc" "kubernetes" {
    cidr_block = var.cidr_block
    enable_dns_hostnames = true
    tags = {
        Name = "kubernetes"
    }
}

#TODO include VPC peering

resource "aws_subnet" "kubernetes" {
    count = length(var.availablity_zones)
    vpc_id = aws_vpc.kubernetes.id
    cidr_block = cidrsubnet(aws_vpc.kubernetes.cidr_block, var.subnet_mask, count.index)
    availability_zone = element(var.availablity_zones, count.index)
    tags = {
        Name = format("%v-subnet-%v", aws_vpc.kubernetes.id, element(var.availablity_zones, count.index))
        format("kubernetes.io/cluster/%v", var.cluster_name) = "owned"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.kubernetes.id
}

resource "aws_route_table" "kubernetes-rt" {
    vpc_id = aws_vpc.kubernetes.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    lifecycle {
      ignore_changes = all
    }
}

resource "aws_route_table_association" "kubernetes" {
    route_table_id = aws_route_table.kubernetes-rt.id
    count = length(var.availablity_zones)
    subnet_id = element(aws_subnet.kubernetes.*.id, count.index)
}


resource "aws_security_group" "kubernetes-sg" {
    vpc_id = aws_vpc.kubernetes.id
    name = "kubernetes-sg"
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }
    ingress {
        from_port =22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port =0
        to_port = 65535
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = format("sg-%v", var.cluster_name)
        format("kubernetes.io/cluster/%v", var.cluster_name) = "owned"
    }

}

#######

## IAM Roles

######

#####
# IAM roles
#####

# Master

data "template_file" "master_policy_json" {
  template = file("${path.module}/template/master-policy.json.tpl")

  vars = {}
}

resource "aws_iam_policy" "master_policy" {
  name        = "${var.cluster_name}-master"
  path        = "/"
  description = "Policy for role ${var.cluster_name}-master"
  policy      = data.template_file.master_policy_json.rendered
}

resource "aws_iam_role" "master_role" {
  name = "${var.cluster_name}-master"

  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_policy_attachment" "master-attach" {
  name = "master-attachment"
  roles = [aws_iam_role.master_role.name]
  policy_arn = aws_iam_policy.master_policy.arn
}

resource "aws_iam_instance_profile" "master_profile" {
  name = "${var.cluster_name}-master"
  role = aws_iam_role.master_role.name
}

# Node

data "template_file" "node_policy_json" {
  template = file("${path.module}/template/node-policy.json.tpl")

  vars = {}
}

resource "aws_iam_policy" "node_policy" {
  name = "${var.cluster_name}-node"
  path = "/"
  description = "Policy for role ${var.cluster_name}-node"
   policy = data.template_file.node_policy_json.rendered
}

resource "aws_iam_role" "node_role" {
  name = "${var.cluster_name}-node"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_policy_attachment" "node-attach" {
  name       = "node-attachment"
  roles      = [aws_iam_role.node_role.name]
  policy_arn = aws_iam_policy.node_policy.arn
}

resource "aws_iam_instance_profile" "node_profile" {
  name = "${var.cluster_name}-node"
  role = aws_iam_role.node_role.name
}

#etcd

resource "aws_iam_user" "etcd-backuper" {
    count = var.etcd_backup_keys
    name  = "etcd-backuper-${var.cluster_name}"
    path  = "/system/"
}

resource "aws_iam_access_key" "etc-backuper" {
    count = var.etcd_backup_keys
    user = element(aws_iam_user.etcd-backuper.*.name, count.index)
}

data "template_file" "etcd_policy_json" {
  template = file("${path.module}/template/etcd-policy.json.tpl")

  vars = {}
}


resource "aws_iam_policy" "etcd-backuper-policy" {
    name = "etcd-backup-policy"
    policy = data.template_file.etcd_policy_json.rendered
}

resource "aws_iam_policy_attachment" "etcd-policy-attachment" {
    count = var.etcd_backup_keys
    name = "etcd-${var.cluster_name}"
    users = [element(aws_iam_user.etcd-backuper.*.name, count.index)]
    policy_arn = aws_iam_policy.etcd-backuper-policy.arn
}


module "master" {
    source = "./modules/master"
    vpc_id = aws_vpc.kubernetes.id
    key_name = aws_key_pair.kubernetes.id
    ssh_private_key = var.private_key_file
    iam_instance_profile_id = aws_iam_instance_profile.master_profile.id
    subnet_ids = aws_subnet.kubernetes.*.id
    azs =    var.availablity_zones
    security_group_ids = [aws_security_group.kubernetes-sg.id]
    cluster_name = var.cluster_name
    s3_bucket = var.userdata_s3_bucket
}

module "worker" {
    source = "./modules/worker"
    vpc_id = aws_vpc.kubernetes.id
    min_worker_count = "1"
    max_worker_count = "1"
    master_alb_dns = module.master.master_ip
    key_name = aws_key_pair.kubernetes.id
    ssh_private_key = var.private_key_file
    instance_profile = aws_iam_instance_profile.node_profile.id
    worker_subnet_ids = aws_subnet.kubernetes.*.id
    security_group_ids = [aws_security_group.kubernetes-sg.id]
    cluster_name = var.cluster_name
    bucket_name = var.userdata_s3_bucket

} 








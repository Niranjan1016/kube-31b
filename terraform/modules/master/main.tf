module "ami" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami"
  region = var.region
  distribution = "xenial"
  virttype = "hvm"
  storagetype = "ebs-ssd"
}

resource "aws_alb" "controller" {
    name = "tf-master-${var.cluster_name}"
    internal = true
    security_groups = var.security_group_ids
    subnets = var.subnet_ids
    tags  = {
        terraform_module = "master"
    }
}

resource "aws_alb_target_group" "controller" {
    name = "tf-master-${var.cluster_name}"
    port = 6433
    protocol = "HTTP"
    vpc_id = var.vpc_id
    health_check {
        path = "/healthz"
        port = 8080

    }
}

data "template_file" "user_data" {
  template = file("${path.module}/template/user_data.sh.tpl")

  vars = {
    BUCKET_NAME = var.ansible_bucket_name
    DEPLOYMENT_PREFIX = var.deployment_artifacts
    kubernetes_version = var.kubernetes_version
    cluster_name = var.cluster_name
#    master_alb_dns = aws_alb.controller.dns_name
  }
}

resource "aws_instance" "master"{
    ami = module.ami.ami_id
    instance_type = var.instance_type
    iam_instance_profile =  var.iam_instance_profile_id
    subnet_id = element(var.subnet_ids, 0)
    associate_public_ip_address = true
    availability_zone = element(var.azs, 0)
    vpc_security_group_ids = var.security_group_ids
    key_name = var.key_name
    user_data  =  data.template_file.user_data.rendered
    tags = {

        Name = "kube-master"
        ansible_managed = "yes"
        kubernetes_role = "controller"
        terraform_module = "master"
        format("kubernetes.io/cluster/%v", var.cluster_name) = "owned"

    }
}

resource "null_resource" "wait_for_bootstrap_to_finish" {
  provisioner "local-exec" {
    command = <<-EOF
    while true; do
      sleep 2
      ! ssh -q -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${aws_instance.master.public_ip} [[ -f /home/ubuntu/completed ]] >/dev/null && continue
      break
    done
    EOF
  }
  triggers = {
    instance_ids = aws_instance.master.id
  }
}

locals {
  kubeconfig_file = "${abspath(pathexpand(var.kubeconfig_dir))}/config"
}

resource "null_resource" "download_kubeconfig_file" {
  provisioner "local-exec" {
    command = <<-EOF
    scp -q -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${aws_instance.master.public_ip}:/home/ubuntu/admin.conf ${local.kubeconfig_file} >/dev/null
    EOF
  }
  triggers = {
    wait_for_bootstrap_to_finish = null_resource.wait_for_bootstrap_to_finish.id
  }
}

resource "aws_alb_listener" "controller" {
    load_balancer_arn = aws_alb.controller.id
    port    = "6443"
    protocol = "HTTP"
    default_action {
        target_group_arn = aws_alb_target_group.controller.id
        type = "forward"
    }
}

resource "aws_alb_target_group_attachment" "controller" {
    count = var.master_instances
    target_group_arn = aws_alb_target_group.controller.id
    target_id = element(aws_instance.master.*.id, count.index)
    port = 6443
}



resource "aws_alb_target_group" "controller_8080" {
    name = "tf-master-8080-${var.cluster_name}"
    port = 8080
    protocol = "HTTP"
    vpc_id = var.vpc_id
    health_check {
        path = "/healthz"
        port = 8080

    }
}

resource "aws_alb_listener" "controller_8080" {
    load_balancer_arn = aws_alb.controller.id
    port    = "8080"
    protocol = "HTTP"
    default_action {
        target_group_arn = aws_alb_target_group.controller_8080.id
        type = "forward"
    }
}

resource "aws_alb_target_group_attachment" "controller_8080" {
    count = var.master_instances
    target_group_arn = aws_alb_target_group.controller_8080.id
    target_id = element(aws_instance.master.*.id, count.index)
    port = 8080
}





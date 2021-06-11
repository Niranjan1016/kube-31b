module "ami" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami"
  region = var.region
  distribution = "xenial"
  virttype = "hvm"
  storagetype = "ebs-ssd"
}

data "template_file" "user_data" {
  template = file("${path.module}/template/user_data.sh.tpl")

  vars = {
    BUCKET_NAME = var.ansible_bucket_name
    DEPLOYMENT_PREFIX = var.deployment_artifacts
    cluster_name = var.cluster_name
    master_alb_dns = var.master_alb_dns
  }
}

resource "aws_launch_configuration" "nodes" {
  name_prefix          = "${var.cluster_name}-nodes-"
  image_id             = module.ami.ami_id
  instance_type        = var.worker_instance_type
  key_name             = var.key_name
  iam_instance_profile = var.instance_profile
  security_groups = var.security_group_ids
  associate_public_ip_address = true
  user_data =  data.template_file.user_data.rendered
  root_block_device {
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = true
  }
}

resource "aws_autoscaling_group" "nodes" {
  vpc_zone_identifier = var.worker_subnet_ids

  name                 = "${var.cluster_name}-nodes"
  max_size             = var.max_worker_count
  min_size             = var.min_worker_count
  desired_capacity     = var.min_worker_count
  launch_configuration = aws_launch_configuration.nodes.name

  tags = concat(
    [{
      key                 = "kubernetes.io/cluster/${var.cluster_name}"
      value               = "owned"
      propagate_at_launch = true
    },
    {
      key                 = "Name"
      value               = "${var.cluster_name}-node"
      propagate_at_launch = true
    }],
    var.tags2,
  )

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}


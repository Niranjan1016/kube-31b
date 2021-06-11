#! /bin/bash

sudo apt-get update && sudo apt-get install -y python3 awscli
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
sudo echo "******************Installing ansible playbooks***************************"
[-d /var/ansible ] && sudo rm -rf /var/ansible
sudo mkdir -p /var/ansible/
cd /var/ansible/
aws s3 cp s3://${BUCKET_NAME}/${DEPLOYMENT_PREFIX}/ansible.tar.gz master-userdata.tar.gz
tar -xzvf master-userdata.tar.gz
ls -lrt
export FULL_HOSTNAME="$(curl -s http://169.254.169.254/latest/meta-data/hostname)"
export token="b0f7b8.8d1767876297d85c"
ansible-playbook master-site.yml -i hosts/hosts.ini --limit master --extra-vars "token=$token kubernetes_version=${kubernetes_version} cluster_name=${cluster_name} hostname=$FULL_HOSTNAME master_alb_dns=${master_alb_dns}"

if [ -f /home/ubuntu/admin.conf]; then
    touch /home/ubuntu/completed
fi


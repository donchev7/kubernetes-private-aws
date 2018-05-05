#!/bin/bash

cat <<EOF > /tmp/setup.sh

cd /opt/

function install_packages {
    # Set apt-get proxy
    echo 'Acquire::http::Proxy "${proxy}";' > /etc/apt/apt.conf
    echo 'Acquire::https::Proxy "${proxy}";' > /etc/apt/apt.conf
    apt update
    apt -y install awscli jq
}


function copy_script_directory {
    aws s3 cp s3://${s3_id}/scripts . --region eu-central-1 --recursive
    chmod +x installation/*.sh
    chmod +x installation/redsocks
    mv installation/redsocks /usr/local/bin
}

function setup {
   ./installation/1a_setup_redsocks.sh ${proxy}
   ./installation/1_prepare.sh 
   ./installation/2_setup_kubernetes.sh

   if [ "${role}" == "master" ]; then
     ./installation/3_addons.sh
   fi
}

function setup_terraform_directory {
    mkdir /etc/terraform/
    echo "${s3_id}" > /etc/terraform/s3_bucket
    echo "${role}" > /etc/terraform/role
    echo "${volume}" > /etc/terraform/volume
    echo "${load_balancer_dns}" > /etc/terraform/load_balancer_dns
    dig +short ${load_balancer_dns} | head -1 > /etc/terraform/load_balancer_ip
}

function setup_iptables {
  # aws nlb does direct routing
  # that means the packages are forwarded with the same source ip 
  # which doesn't work when sender and receiver are equal
  echo "#!/bin/sh -e" > /etc/rc.local
  echo "ip route add local \$(cat /etc/terraform/load_balancer_ip) dev eth0  proto kernel  scope host  src \$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)" >> /etc/rc.local
  echo "exit 0" >> /etc/rc.local

  /etc/rc.local
}

setup_terraform_directory
if [ "${role}" == "master" ]; then
  setup_iptables
fi

install_packages

copy_script_directory

setup

EOF

sudo su -c "bash -x /tmp/setup.sh"

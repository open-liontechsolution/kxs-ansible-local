#!/bin/bash

# Leer las IPs del archivo de salida de Terraform
master_first_host=$(jq -r '.ec2_kxs_master_public_ip.value' ../kxs-terraform/output.json)
master_first_private_dns=$(jq -r '.ec2_kxs_master_private_dns.value' ../kxs-terraform/output.json)
worker1_host=$(jq -r '.ec2_kxs_worker_public_ip.value' ../kxs-terraform/output.json)
mariadb_host=$(jq -r '.ec2_kxs_mariadb_public_ip.value' ../kxs-terraform/output.json)
mariadb_private_dns=$(jq -r '.ec2_kxs_mariadb_private_dns.value' ../kxs-terraform/output.json)

# Leer las contraseñas de los archivos group_vars y host locales
mariadb_pass=$(yq eval '.k3s_database_pass' group_vars/mariadb.yaml)
master2_host=$(yq eval '.master2_host' group_vars/masters.yaml)
master2_pass=$(yq eval '.master2_pass' group_vars/masters.yaml)
worker2_host=$(yq eval '.worker2_host' group_vars/workers.yaml)
worker2_pass=$(yq eval '.worker2_pass' group_vars/workers.yaml)

# Crear las entradas de inventario
echo "[master_first]" > inventory.ini
echo "master1 ansible_host=$master_first_host ansible_user=admin ansible_ssh_private_key_file=~/.ssh/kxs_master.pem" >> inventory.ini

echo "[masters]" >> inventory.ini
echo "master2 ansible_host=$master2_host ansible_user=pi ansible_ssh_pass=$master2_pass" >> inventory.ini

echo "[workers]" >> inventory.ini
echo "worker1 ansible_host=$worker1_host ansible_user=admin ansible_ssh_private_key_file=~/.ssh/kxs_worker.pem" >> inventory.ini
echo "[workers_local]" >> inventory.ini
echo "worker2 ansible_host=$worker2_host ansible_user=pi ansible_ssh_pass=$worker2_pass" >> inventory.ini

echo "[mariadb]" >> inventory.ini
echo "mariadb1 ansible_host=$mariadb_host ansible_user=admin ansible_ssh_private_key_file=~/.ssh/kxs_mariadb.pem" >> inventory.ini

# metemos datos de variables para mariadb
sed -i "/^k3s_client_host/c\k3s_client_host: $master_first_private_dns" group_vars/mariadb.yaml
cluster_db="mysql://k3s_user:$mariadb_pass@tcp($mariadb_private_dns:3306)/k3s"
sed -i "/^cluster_db/c\cluster_db: $cluster_db" group_vars/master_first.yaml

# metemos datos de variables para el master_first
sed -i "/^master_first_ip_public/c\master_first_ip_public: $master_first_host" group_vars/master_first.yaml

# worker private ip master
sed -i "/^worker1_host/c\worker1_host: $worker1_host" group_vars/workers.yaml
sed -i "/^first_master_dns/c\first_master_dns: $master_first_private_dns" group_vars/workers.yaml
# worker public ip master
sed -i "/^first_master_public_ip/c\first_master_public_ip: $master_first_host" group_vars/workers_local.yaml

export KUBECONFIG=/home/juanjocop/.k3s/config

sed -i "s/127.0.0.1/$master_first_host/g" ~/.k3s/config
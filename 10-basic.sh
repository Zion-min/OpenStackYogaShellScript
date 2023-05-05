#!/bin/bash
## 01-basic.sh
source ./config.sh

echo "set environments..."

## NTP Installation
## 테스트 스크립트 편의상 0.0.0.0/0 으로 할당하였습니다. 원래는 해당 서브넷만 주셔야 합니다.
PKGS='chrony'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S sed -i '$ a server time.google.com iburst\nallow 10.0.2.0/0' /etc/chrony/chrony.conf
echo ${HOST_pass[0]} | sudo -S service chrony restart
## Add Repository
echo ${HOST_pass[0]} | sudo -S add-apt-repository cloud-archive:yoga
## Install openstack client
PKGS='python3-openstackclient'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi

cat config.sh > basic.sh
cat << "EOZ" >> basic.sh
# 컴퓨터 서버 수에 따라 호스트네임 추가
for ((i = 0; i <= $COMPUTENODE; i++))
do
    echo ${HOST_pass[0]} | sudo -S sed -i '$ a '${HOST_ip[$i]}' '${HOST_name[$i]} /etc/hosts
done
#chrony 설치
PKGS='chrony'
if [ $QUIETAPT -eq 1 ]; then echo $HOST_pass[1] | sudo -S apt install -q -y $PKGS; else ${HOST_pass[1]} | sudo -S apt install -y $PKGS; fi
# chrony 설정
echo ${HOST_pass[1]} | sudo -S sed -i "/^server/ s/^#*/#/" /etc/chrony/chrony.conf
echo ${HOST_pass[1]} | sudo -S sed -i '$ a server '${HOST_name[0]}' iburst' /etc/chrony/chrony.conf
echo ${HOST_pass[1]} | sudo -S service chrony restart
## Add Repository
echo ${HOST_pass[1]} | sudo -S add-apt-repository cloud-archive:yoga
## Install openstack client
PKGS='python3-openstackclient'
if [ $QUIETAPT -eq 1 ]; then echo $HOST_pass[1] | sudo -S apt install -q -y $PKGS; else ${HOST_pass[1]} | sudo -S apt install -y $PKGS; fi
EOZ

for ((i = 1; i <= $COMPUTENODE; i++))
do
    ssh ${HOST_name[$i]} 'bash -s' < basic.sh
done

########## Basic Openstack config for controller
## Install Mariadb
PKGS='mariadb-server python3-pymysql'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S bash -c "echo '
[mysqld]
bind-address = '${HOST_ip[0]}'
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
' > /etc/mysql/mariadb.conf.d/99-openstack.cnf"
echo ${HOST_pass[0]} | sudo -S service mysql restart
echo ${HOST_pass[0]} | sudo -S bash -c 'echo -e "\n\n'$DBPASS'\n'$DBPASS'\ny\nn\ny\ny\n " | /usr/bin/mysql_secure_installation'
#mysql -u root -p$DBPASS -e "set global max_connections = 4096;"

## Install RABBIT MQ 
PKGS='rabbitmq-server'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S rabbitmqctl add_user openstack $RABBIT_PASS
echo ${HOST_pass[0]} | sudo -S rabbitmqctl set_permissions openstack ".*" ".*" ".*"

## Install memcached
PKGS='memcached python3-memcache'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S sed -i "s/-l 127.0.0.1/-l ${HOST_name[0]}/g" /etc/memcached.conf
echo ${HOST_pass[0]} | sudo -S service memcached restart

PKGS='etcd'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi

echo ${HOST_pass[0]} | sudo -S bash -c "echo '
ETCD_NAME=\"controller\"
ETCD_DATA_DIR=\"/var/lib/etcd\"
ETCD_INITIAL_CLUSTER_STATE=\"new\"
ETCD_INITIAL_CLUSTER_TOKEN=\"etcd-cluster-01\"
ETCD_INITIAL_CLUSTER=\"controller=http://"${HOST_ip[0]}":2380\"
ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://"${HOST_ip[0]}":2380\"
ETCD_ADVERTISE_CLIENT_URLS=\"http://"${HOST_ip[0]}":2379\"
ETCD_LISTEN_PEER_URLS=\"http://0.0.0.0:2380\"
ETCD_LISTEN_CLIENT_URLS=\"http://"${HOST_ip[0]}":2379\"
' >> /etc/default/etcd"

echo ${HOST_pass[0]} | sudo -S systemctl enable etcd
echo ${HOST_pass[0]} | sudo -S systemctl restart etcd

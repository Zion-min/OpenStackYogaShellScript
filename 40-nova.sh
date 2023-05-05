#!/bin/bash
source ./config.sh

echo "install nova..."

echo ${HOST_pass[0]} | sudo -S mysql -u root -p$DBPASS -e "CREATE DATABASE placement; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '"$PLACEMENT_DBPASS"'; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '"$PLACEMENT_DBPASS"';"
. ~/admin-openrc

/usr/bin/expect <<EOE
set prompt "#"
spawn bash -c "openstack user create --domain default --password-prompt placement"
expect {
  -nocase "password" {send "$PLACEMENT_PASS\r"; exp_continue }
  -nocase "password" {send "$PLACEMENT_PASS\r"; exp_continue }
  $prompt
}
EOE
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://${HOST_name[0]}:8778
openstack endpoint create --region RegionOne placement internal http://${HOST_name[0]}:8778
openstack endpoint create --region RegionOne placement admin http://${HOST_name[0]}:8778

echo ${HOST_pass[0]} | sudo -S apt install placement-api
PKGS='placement-api python3-pip'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi

echo ${HOST_pass[0]} | sudo -S cp /etc/placement/placement.conf ./backup/placement.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/placement/placement.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/placement/placement.conf
echo ${HOST_pass[0]} | sudo -S sed -i "s/connection = sqlite/\#connection = sqlite/" /etc/placement/placement.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[placement_database\]/a connection = mysql+pymysql://placement:"$PLACEMENT_DBPASS"@"${HOST_name[0]}"/placement" /etc/placement/placement.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/\[api\]/a auth_strategy = keystone' /etc/placement/placement.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[keystone_authtoken\]/a auth_url = http://"${HOST_name[0]}":5000/v3\nmemcached_servers = "${HOST_name[0]}":11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = placement\npassword = "$PLACEMENT_PASS"" /etc/placement/placement.conf

echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "placement-manage db sync" placement
echo ${HOST_pass[0]} | sudo -S service apache2 restart

pip3 install osc-placement

########## Nova for controller
## Create DB
echo ${HOST_pass[0]} | sudo -S mysql -u root -p$DBPASS -e "CREATE DATABASE nova_api; CREATE DATABASE nova; CREATE DATABASE nova_cell0; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '"$NOVA_DBPASS"'; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '"$NOVA_DBPASS"'; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '"$NOVA_DBPASS"'; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '"$NOVA_DBPASS"'; GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '"$NOVA_DBPASS"'; GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '"$NOVA_DBPASS"';"

/usr/bin/expect <<EOE
set prompt "#"
spawn bash -c "openstack user create --domain default --password-prompt nova"
expect {
  -nocase "password" {send "$NOVA_PASS\r"; exp_continue }
  -nocase "password" {send "$NOVA_PASS\r"; exp_continue }
  $prompt
}
EOE
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://${HOST_name[0]}:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://${HOST_name[0]}:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://${HOST_name[0]}:8774/v2.1

PKGS='nova-api nova-conductor nova-novncproxy nova-scheduler'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S cp /etc/nova/nova.conf ./backup/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/nova/nova.conf

echo ${HOST_pass[0]} | sudo -S sed -i "s/connection = sqlite/\#connection = sqlite/" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[DEFAULT\]/a my_ip = "${HOST_ip[0]}"\ntransport_url = rabbit://openstack:"$RABBIT_PASS"@"${HOST_name[0]}":5672/\n" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[api_database\]/a connection = mysql+pymysql://nova:"$NOVA_DBPASS"@"${HOST_name[0]}"/nova_api" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[database\]/a connection = mysql+pymysql://nova:"$NOVA_DBPASS"@"${HOST_name[0]}"/nova" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/\[api\]/a auth_strategy = keystone' /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[keystone_authtoken\]/a www_authenticate_uri = http://"${HOST_name[0]}":5000\nauth_url = http://"${HOST_name[0]}":5000\nmemcached_servers = ${HOST_name[0]}:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = "$NOVA_PASS"" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[vnc\]/a enabled = true\nvncserver_listen = \$my_ip\nvncserver_proxyclient_address = \$my_ip" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[glance\]/a api_servers = http://"${HOST_name[0]}":9292" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/\[oslo_concurrency\]/a lock_path = /var/lib/nova/tmp' /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[placement\]/a region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://"${HOST_name[0]}":5000/v3\nusername = placement\npassword = "$PLACEMENT_PASS"" /etc/nova/nova.conf

echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "nova-manage api_db sync" nova
echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "nova-manage db sync" nova
echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
echo ${HOST_pass[0]} | sudo -S service nova-api restart
echo ${HOST_pass[0]} | sudo -S service nova-scheduler restart
echo ${HOST_pass[0]} | sudo -S service nova-conductor restart
echo ${HOST_pass[0]} | sudo -S service nova-novncproxy restart

########## Nova for compute
if [ $COMPUTENODE -eq 0 ]
then
PKGS='nova-compute'
if [ $QUIETAPT -eq 1 ]; then echo %{HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S cp /etc/nova/nova.conf ./backup/nova.conf2
echo ${HOST_pass[0]} | sudo -S sed -i "/\[vnc\]/a novncproxy_base_url = http://${HOST_ip[0]}:6080/vnc_auto.html" /etc/nova/nova.conf
echo ${HOST_pass[0]} | sudo -S service nova-compute restart

elif [ $COMPUTENODE -ge 1 ]
then
cat config.sh > nova.sh
echo 'NODE_IP=' >> nova.sh
echo 'NODE_PASS=' >> nova.sh
cat << "EOZ" >> nova.sh
PKGS='nova-compute'
if [ $QUIETAPT -eq 1 ]; then echo $NODE_PASS | sudo -S apt install -q -y $PKGS; else echo $NODE_PASS | sudo -S apt install -y $PKGS; fi
echo $NODE_PASS | sudo -S cp /etc/nova/nova.conf /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i '/^#/d' /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i '/^$/d' /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i "/\[DEFAULT\]/a my_ip = "${NODE_IP}"\ntransport_url = rabbit://openstack:"$RABBIT_PASS"@"${HOST_name[0]}"" /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i '/\[api\]/a auth_strategy = keystone' /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i "/\[keystone_authtoken\]/a www_authenticate_uri = http://${HOST_name[0]}:5000\nauth_url = http://${HOST_name[0]}:5000\nmemcached_servers = ${HOST_name[0]}:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = "$NOVA_PASS"" /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i "/\[vnc\]/a enabled = True\nvncserver_listen = 0.0.0.0\nvncserver_proxyclient_address = \$my_ip\nnovncproxy_base_url = http://${HOST_ip[0]}:6080/vnc_auto.html" /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i "/\[glance\]/a api_servers = http://${HOST_name[0]}:9292" /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i '/\[oslo_concurrency\]/a lock_path = /var/lib/nova/tmp' /etc/nova/nova.conf
echo $NODE_PASS | sudo -S sed -i "/\[placement\]/a region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://${HOST_name[0]}:5000/v3\nusername = placement\npassword = "$PLACEMENT_PASS"" /etc/nova/nova.conf
echo $NODE_PASS | sudo -S service nova-compute restart

EOZ
for ((i = 1; i <= $COMPUTENODE; i++))
do
sed -i "/^NODE_IP/c\NODE_IP=\${HOST_ip[$i]}" nova.sh
sed -i "/^NODE_PASS/c\NODE_PASS=\${HOST_pass[$i]}" nova.sh
ssh ${HOST_name[$i]} 'bash -s' < nova.sh
done
fi

echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
#nova-status upgrade check

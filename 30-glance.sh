#!/bin/bash
source ./config.sh

echo "install glance..."

########## Glance for controller
echo ${HOST_pass[0]} | sudo -S mysql -u root -p$DBPASS -e "CREATE DATABASE glance; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS'; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';"
. ~/admin-openrc

/usr/bin/expect <<EOE
set prompt "#"
spawn bash -c "openstack user create --domain default --password-prompt glance"
expect {
  -nocase "password" {send "$GLANCE_PASS\r"; exp_continue }
  -nocase "password" {send "$GLANCE_PASS\r"; exp_continue }
  $prompt
}
EOE
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://${HOST_name[0]}:9292
openstack endpoint create --region RegionOne image internal http://${HOST_name[0]}:9292
openstack endpoint create --region RegionOne image admin http://${HOST_name[0]}:9292

openstack role add --user glance --user-domain Default --system all reader

PKGS='glance'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S cp /etc/glance/glance-api.conf ./backup/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i "s/connection = sqlite/\#connection = sqlite/" /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[database\]/a connection = mysql+pymysql://glance:"$GLANCE_DBPASS"@"${HOST_name[0]}"/glance" /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[keystone_authtoken\]/a www_authenticate_uri = http://"${HOST_name[0]}":5000\nauth_url = http://"${HOST_name[0]}":5000\nmemcached_servers = "${HOST_name[0]}":11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = glance\npassword = "$GLANCE_PASS"" /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/\[paste_deploy\]/a flavor = keystone' /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/\[glance_store\]/a stores = file,http\ndefault_store = file\nfilesystem_store_datadir = /var/lib/glance/images/' /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i "$ a \[oslo_limit\]\nauth_url = http://"${HOST_name[0]}":5000\nauth_type = password\nuser_domain_id = default\nusername = glance\nsystem_scope = all\npassword = "$GLANCE_PASS"\nendpoint_id = ENDPOINT_ID\nregion_name = RegionOne" /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[default\]/a use_keystone_quotas = True\n" /etc/glance/glance-api.conf
echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "glance-manage db_sync" glance
echo ${HOST_pass[0]} | sudo -S service glance-api restart

wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
glance image-create --name "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility=public
glance image-list

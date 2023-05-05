#!/bin/bash
source ./config.sh

echo "install keystone..."

########## Keystone for controller
echo ${HOST_pass[0]} | sudo -S mysql -uroot -p$DBPASS -e "CREATE DATABASE keystone; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS'; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';"
PKGS='keystone'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
# 기존 파일은 backup. 으로 저장 sed를 통해 #으로 시작하는 줄(주석)과 빈줄이 모두 삭제됩니다. 이후 모든 컨피그 파일 동일.
echo ${HOST_pass[0]} | sudo -S cp /etc/keystone/keystone.conf ./backup/keystone.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/keystone/keystone.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/keystone/keystone.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[database\]/a connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@${HOST_name[0]}/keystone" /etc/keystone/keystone.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/\[token\]/a provider = fernet' /etc/keystone/keystone.conf
echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "keystone-manage db_sync" keystone

echo ${HOST_pass[0]} | sudo -S keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
echo ${HOST_pass[0]} | sudo -S keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
echo ${HOST_pass[0]} | sudo -S keystone-manage bootstrap --bootstrap-password $ADMIN_PASS --bootstrap-admin-url http://${HOST_name[0]}:5000/v3/ --bootstrap-internal-url http://${HOST_name[0]}:5000/v3/ --bootstrap-public-url http://${HOST_name[0]}:5000/v3/ --bootstrap-region-id RegionOne
echo ${HOST_pass[0]} | sudo -S sed -i "$ a ServerName ${HOST_name[0]}" /etc/apache2/apache2.conf
echo ${HOST_pass[0]} | sudo -S service apache2 restart
## Creating Domain
echo "export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://${HOST_name[0]}:5000/v3
export OS_IDENTITY_API_VERSION=3
" > ~/admin-openrc
. ~/admin-openrc

openstack domain create --description "An Example Domain" example
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" myproject

/usr/bin/expect <<EOE
set prompt "#"
spawn bash -c "openstack user create --domain default --password-prompt myuser"
expect {
  -nocase "password" {send "$USER_PASS\r"; exp_continue }
  $prompt
}
EOE

#openstack user create --domain default --password-prompt myuser
openstack role create myrole
openstack role add --project myproject --user myuser myrole

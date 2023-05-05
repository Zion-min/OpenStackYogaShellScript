#!/bin/bash
source ./config.sh

echo "install neutron..."

########## Neutron for controller
## Create DB
echo ${HOST_pass[0]} | sudo -S mysql -u root -p$DBPASS -e "CREATE DATABASE neutron; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '"$NEUTRON_DBPASS"'; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '"$NEUTRON_DBPASS"';"
. ~/admin-openrc

/usr/bin/expect <<EOE
set prompt "#"
spawn bash -c " openstack user create --domain default --password-prompt neutron"
expect {
  -nocase "password" {send "$NEUTRON_PASS\r"; exp_continue }
  -nocase "password" {send "$NEUTRON_PASS\r"; exp_continue }
  $prompt
}
EOE

openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://${HOST_name[0]}:9696
openstack endpoint create --region RegionOne network internal http://${HOST_name[0]}:9696
openstack endpoint create --region RegionOne network admin http://${HOST_name[0]}:9696
PKGS='neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS; else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi
echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/neutron.conf /etc/neutron/backup.neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i "s/connection = sqlite/\#connection = sqlite/" /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[database\]/a connection = mysql+pymysql://neutron:"$NEUTRON_DBPASS"@"${HOST_name[0]}"/neutron" /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[DEFAULT\]/a core_plugin = ml2\nservice_plugins = router\nallow_overlapping_ips = true\ntransport_url = rabbit://openstack:"$RABBIT_PASS"@"${HOST_name[0]}"\nauth_strategy = keystone\nnotify_nova_on_port_status_changes = true\nnotify_nova_on_port_data_changes = true" /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[keystone_authtoken\]/a www_authenticate_uri = http://"${HOST_name[0]}":5000\nauth_url = http://"${HOST_name[0]}":5000\nmemcached_servers = "${HOST_name[0]}":11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = "$NEUTRON_PASS"" /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i "/\[nova\]/a auth_url = http://"${HOST_name[0]}":5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = nova\npassword = "$NOVA_PASS"" /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S sed -i '/\[oslo_concurrency\]/a lock_path = /var/lib/neutron/tmp' /etc/neutron/neutron.conf
echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/backup.ml2_conf.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/neutron/plugins/ml2/ml2_conf.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/neutron/plugins/ml2/ml2_conf.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/\[ml2\]/a type_drivers = flat,vlan,vxlan\ntenant_network_types = vxlan\nmechanism_drivers = linuxbridge,l2population\nextension_drivers = port_security' /etc/neutron/plugins/ml2/ml2_conf.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/\[ml2_type_flat\]/a flat_networks = provider' /etc/neutron/plugins/ml2/ml2_conf.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/\[ml2_type_vxlan\]/a vni_ranges = 1:1000' /etc/neutron/plugins/ml2/ml2_conf.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/\[securitygroup\]/a enable_ipset = true' /etc/neutron/plugins/ml2/ml2_conf.ini
echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/backup.linuxbridge_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i "/\[linux_bridge\]/a physical_interface_mappings = provider:"$(ip a | grep -B 2 ${HOST_prov_ip[0]} | grep UP | awk -F: {'print $2'} | tr -d ' ')"" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i "/\[vxlan\]/a enable_vxlan = true\nlocal_ip = "${HOST_ip[0]}"\nl2_population = true" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/\[securitygroup\]/a enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' /etc/neutron/plugins/ml2/linuxbridge_agent.ini

echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/l3_agent.ini /etc/neutron/backup.l3_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/neutron/l3_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/neutron/l3_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/\[DEFAULT\]/a interface_driver = linuxbridge' /etc/neutron/l3_agent.ini

echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/dhcp_agent.ini /etc/neutron/backup.dhcp_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/neutron/dhcp_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/neutron/dhcp_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i "/\[DEFAULT\]/a interface_driver = linuxbridge\ndhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\nenable_isolated_metadata = true" /etc/neutron/dhcp_agent.ini

echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/metadata_agent.ini /etc/neutron/backup.metadata_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^#/d' /etc/neutron/metadata_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i '/^$/d' /etc/neutron/metadata_agent.ini
echo ${HOST_pass[0]} | sudo -S sed -i "/\[DEFAULT\]/a nova_metadata_ip ="${HOST_name[0]}"\nmetadata_proxy_shared_secret = "$METADATA_SECRET"" /etc/neutron/metadata_agent.ini

echo ${HOST_pass[0]} | sudo -S sed -i "/\[neutron\]/a auth_url = http://"${HOST_name[0]}":5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = "$NEUTRON_PASS"\nservice_metadata_proxy = true\nmetadata_proxy_shared_secret = "$METADATA_SECRET"" /etc/nova/nova.conf
#ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

echo ${HOST_pass[0]} | sudo -S su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
echo ${HOST_pass[0]} | sudo -S service nova-api restart
echo ${HOST_pass[0]} | sudo -S service neutron-server restart
echo ${HOST_pass[0]} | sudo -S service neutron-linuxbridge-agent restart
echo ${HOST_pass[0]} | sudo -S service neutron-dhcp-agent restart
echo ${HOST_pass[0]} | sudo -S service neutron-metadata-agent restart
echo ${HOST_pass[0]} | sudo -S service neutron-l3-agent restart

########## Neutron for compute
if [ $COMPUTENODE -eq 0 ]
then 
echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/neutron.conf /etc/neutron/backup2.neutron.conf
echo ${HOST_pass[0]} | sudo -S cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/backup2.linuxbridge_agent.ini
echo ${HOST_pass[0]} | sudo -S service nova-compute restart
echo ${HOST_pass[0]} | sudo -S service neutron-linuxbridge-agent restart
elif [ $COMPUTENODE -ge 1 ]
then
cat config.sh > neutron.sh
echo 'NODE_IP=' >> neutron.sh
echo 'NODE_PROV_IP=' >> neutron.sh
echo 'NODE_PASS=' >> neutron.sh
cat << "EOZ" >> neutron.sh
PKGS='neutron-linuxbridge-agent'
if [ $QUIETAPT -eq 1 ]; then echo $NODE_PASS | sudo -S apt install -q -y $PKGS; else echo $NODE_PASS | sudo -S apt install -y $PKGS; fi
echo $NODE_PASS | sudo -S cp /etc/neutron/neutron.conf /etc/neutron/backup.neutron.conf
echo $NODE_PASS | sudo -S sed -i '/^#/d' /etc/neutron/neutron.conf
echo $NODE_PASS | sudo -S sed -i '/^$/d' /etc/neutron/neutron.conf
echo $NODE_PASS | sudo -S sed -i 's/connection = sqlite/\#connection = sqlite/' /etc/neutron/neutron.conf
echo $NODE_PASS | sudo -S sed -i "/\[DEFAULT\]/a transport_url = rabbit://openstack:"$RABBIT_PASS"@"${HOST_name[0]}"\nauth_strategy = keystone" /etc/neutron/neutron.conf
echo $NODE_PASS | sudo -S sed -i "/\[keystone_authtoken\]/a www_authenticate_uri = http://${HOST_name[0]}:5000\nauth_url = http://${HOST_name[0]}:5000\nmemcached_servers = ${HOST_name[0]}:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = "$NEUTRON_PASS"" /etc/neutron/neutron.conf
echo $NODE_PASS | sudo -S sed -i '/\[oslo_concurrency\]/a lock_path = /var/lib/neutron/tmp' /etc/neutron/neutron.conf
echo $NODE_PASS | sudo -S cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/backup.linuxbridge_agent.ini
echo $NODE_PASS | sudo -S sed -i '/^#/d' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo $NODE_PASS | sudo -S sed -i '/^$/d' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo $NODE_PASS | sudo -S sed -i "/\[linux_bridge\]/a physical_interface_mappings = provider:"$(ip a | grep -B 2 ${NODE_PROV_IP} | grep UP | awk -F: {'print $2'} | tr -d ' ')"" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo $NODE_PASS | sudo -S sed -i "/\[vxlan\]/a enable_vxlan = true\nlocal_ip = "${NODE_IP}"\nl2_population = true" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo $NODE_PASS | sudo -S sed -i "/\[securitygroup\]/a enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
echo $NODE_PASS | sudo -S sed -i "/\[neutron\]/a auth_url = http://${HOST_name[0]}:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = "$NEUTRON_PASS"" /etc/nova/nova.conf
echo $NODE_PASS | sudo -S service nova-compute restart
echo $NODE_PASS | sudo -S service neutron-linuxbridge-agent restart
EOZ
for ((i = 1; i <= $COMPUTENODE; i++))
do
sed -i "/^NODE_IP/c\NODE_IP=\${HOST_ip[$i]}" neutron.sh
sed -i "/^NODE_PROV_IP/c\NODE_PROV_IP=\${HOST_prov_ip[$i]}" neutron.sh
sed -i "/^NODE_PASS/c\NODE_PASS=\${HOST_pass[$i]}" neutron.sh
ssh ${HOST_name[$i]} 'bash -s' < neutron.sh
done
fi

openstack network agent-list

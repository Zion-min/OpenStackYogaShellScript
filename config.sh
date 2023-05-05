## config.sh
#https://docs.openstack.org/ocata/install-guide-rdo/overview.html#example-architecture
QUIETAPT=1
INSTALL_HEAT=1
INIT_OPENSTACK=1
COMPUTENODE=2

HOST_ip[0]=10.0.2.11
HOST_prov_ip[0]=192.168.122.21
HOST_name[0]=controller
HOST_user[0]=default20
HOST_pass[0]=qwe123

HOST_ip[1]=10.0.2.31
HOST_prov_ip[1]=192.168.122.25
HOST_name[1]=compute1
HOST_user[1]=default20
HOST_pass[1]=qwe123

HOST_ip[2]=10.0.2.32
HOST_prov_ip[2]=192.168.122.26
HOST_name[2]=compute2
HOST_user[2]=default20
HOST_pass[2]=qwe123

#https://docs.openstack.org/ocata/install-guide-rdo/environment-security.html
DBPASS=qwe123
ADMIN_PASS=qwe123
RABBIT_PASS=qwe123

USER_PASS=qwe123

METADATA_SECRET=qwe123
KEYSTONE_DBPASS=qwe123

GLANCE_DBPASS=qwe123
GLANCE_PASS=qwe123

PLACEMENT_DBPASS=qwe123
PLACEMENT_PASS=qwe123

NOVA_DBPASS=qwe123
NOVA_PASS=qwe123

NEUTRON_DBPASS=qwe123
NEUTRON_PASS=qwe123

DASH_DBPASS=qwe213

HEAT_PASS=qwe123
HEAT_DBPASS=qwe123
HEAT_DOMAIN_PASS=qwe123

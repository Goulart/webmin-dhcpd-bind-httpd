#Conditions:
#c.1 Empty data dir
#c.2 Reused data dir
#d.1 no interfaces
#d.2 one interface
#d.3 two interfaces
#e.1 bind + dhcpd + httpd
#e.2 bind only
#e.3 dhcp only
#e.4 httpd only
#e.5 bind + dhcpd
#e.6 bind + httpd
#e.7 dhcpd + httpd

#c.1 e.1 e.2 e.3 e.4 e.5 e.6 e.7
#d.1 -o- -o- -o- -o- --- --- --- 
#d.2 -o- -o- -o- -o- --- --- ---
#d.3 -o- -o- -o- -o- --- --- ---

#c.2 e.1 e.2 e.3 e.4 e.5 e.6 e.7
#d.1 -o- -o- -o- -o- --- --- ---
#d.2 -o- -o- -o- -o- --- --- ---
#d.3 -o- -o- -o- -o- --- --- ---

DATA_DIR=/etc/docker

# Check versions
echo Checking versions...
(named -V | grep -iq 'bind 9.10.3') || echo Warning: Named version not ok
(dhcpd -V 2>&1 | grep -iq 'DHCP Server 4.3.3') || echo Warning: DHCP server version not ok
(apache2 -v 2>&1 | grep -iq 'Apache/2.4.18') || echo Warning: httpd server version not ok
grep -iq '1.970' /usr/share/webmin/version || echo Webmin server version not ok

# Check for directories
echo Checking directories...
WEBMIN_DATA_DIR=${DATA_DIR}/webmin
BIND_DATA_DIR=${DATA_DIR}/bind
DHCPD_DATA_DIR=${DATA_DIR}/dhcpd
APACHE_DATA_DIR=${DATA_DIR}/httpd
APACHE_WWW_DIR=/var/www
[ -d $WEBMIN_DATA_DIR         ] || echo Warning $WEBMIN_DATA_DIR         not found
[ -d $BIND_DATA_DIR           ] || echo Warning $BIND_DATA_DIR           not found
[ -d $DHCPD_DATA_DIR          ] || echo Warning $DHCPD_DATA_DIR          not found
[ -d ${WEBMIN_DATA_DIR}/etc   ] || echo Warning ${WEBMIN_DATA_DIR}/etc   not found
[ -d ${WEBMIN_DATA_DIR}/dhcpd ] || echo Warning ${WEBMIN_DATA_DIR}/dhcpd not found
[ -d ${BIND_DATA_DIR}/etc     ] || echo Warning ${BIND_DATA_DIR}/etc     not found
[ -d ${BIND_DATA_DIR}/lib     ] || echo Warning ${BIND_DATA_DIR}/lib     not found
[ -d ${BIND_DATA_DIR}/lib     ] || echo Warning ${BIND_DATA_DIR}/lib     not found
[ -d ${APACHE_DATA_DIR}       ] || echo Warning ${APACHE_DATA_DIR}       not found
[ -d ${APACHE_DATA_DIR}/etc   ] || echo Warning ${APACHE_DATA_DIR}/etc   not found
[ -d ${APACHE_DATA_DIR}/lib   ] || echo Warning ${APACHE_DATA_DIR}/lib   not found
[ -d ${APACHE_WWW_DIR}        ] || echo Warning ${APACHE_WWW_DIR}        not found

# Check for files
echo Checking files...
DHCPD_DEFAULT="$DHCPD_DATA_DIR/dhcpdDefaultEnv.sh"
[ -f /var/run/dhcpd/dhcpd.pid          ] || echo Warning: /var/run/dhcpd/dhcpd.pid not found
[ -f $DHCPD_DATA_DIR/dhcpd.conf        ] || echo Warning: $DHCPD_DATA_DIR/dhcpd.conf not found
[ -f $DHCPD_DATA_DIR/dhcpd.leases      ] || echo Warning: $DHCPD_DATA_DIR/dhcpd.leases not found
[ -f $DHCPD_DEFAULT                    ] || echo Warning: $DHCPD_DEFAULT not found
[ -f $APACHE_DATA_DIR/etc/apache2.conf ] || echo Warning: $APACHE_DATA_DIR/etc/apache2.conf not found

# Check for processes
echo Checking for processes running...
ps -p $(egrep '[0-9]+' /var/run/dhcpd/dhcpd.pid) > /dev/null 2>&1 || echo /var/run/dhcpd/dhcpd.pid not ok. DHCPd not running?
ps -p $(egrep '[0-9]+' /var/run/named/named.pid) > /dev/null 2>&1 || echo /var/run/named/named.pid not ok. Named not running?
ps -p $(egrep '[0-9]+' /var/webmin/miniserv.pid) > /dev/null 2>&1 || echo /var/webmin/miniserv.pid not ok. Webmin not running?
ps -p $(egrep '[0-9]+' /var/run/apache2/apache2.pid) > /dev/null 2>&1 || echo /var/run/apache2/apache2.pid not ok. Apache2 not running?

echo Checking for file content...
# #/etc/webmin/dhcpd/config
grep -iq "dhcpd_conf=$DHCPD_DATA_DIR/dhcpd.conf" /etc/webmin/dhcpd/config || echo Some content not found in /etc/webmin/dhcpd/config
# #$DHCPD_DEFAULT
grep -iq "INTERFACES=" $DHCPD_DEFAULT || echo Some content not found in $DHCPD_DEFAULT
# #${DHCPD_DATA_DIR}/dhcpd.conf
grep -iq "subnet" ${DHCPD_DATA_DIR}/dhcpd.conf || echo Some content not found in ${DHCPD_DATA_DIR}/dhcpd.conf
grep -iq "ServerName " $APACHE_DATA_DIR/etc/apache2.conf || echo Some content not found in $APACHE_DATA_DIR/etc/apache2.conf

echo Basic testing ended.
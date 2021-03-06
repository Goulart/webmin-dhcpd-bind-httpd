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

DATA_DIR=${DATA_DIR:-/etc/docker}

ROOT_PASSWORD=password                        
WEBMIN_ENABLED=true                           
WEBMIN_INIT_SSL_ENABLED=true                  
WEBMIN_INIT_REDIRECT_PORT=10000               
WEBMIN_INIT_REFERERS=NONE                     
BIND_USER=bind                                
BIND_VERSION=9.10.3                           
APACHE_VERSION=2.4.18                         
WEBMIN_VERSION=1.970                          
DHCPD_VERSION=4.3.3                           
DHCPD_PROTOCOL=4                              
APACHE_SERVER_NAME=                           
APACHE_HTTPS_PORT=                            
APACHE_HTTP_PORT=                             
APACHE_LOCK_DIR=/var/lock/apache2             
APACHE_RUN_DIR=/var/run/apache2               
APACHE_PID_FILE=${APACHE_RUN_DIR}/apache2.pid 
APACHE_LOG_DIR=/var/log/apache2               
APACHE_RUN_USER=www-data                      
APACHE_RUN_GROUP=www-data                     
APACHE_MAX_REQUEST_WORKERS=32                 
APACHE_MAX_CONNECTIONS_PER_CHILD=1024         
APACHE_ALLOW_OVERRIDE=None                    
APACHE_ALLOW_ENCODED_SLASHES=Off              
APACHE_ERRORLOG=""                            
APACHE_CUSTOMLOG=""                           
APACHE_LOGLEVEL=error                         
APACHE_WWW_DIR=/var/www                       
DATA_DIR=/data

WEBMIN_DATA_DIR=${DATA_DIR}/webmin
ROOT_PASSWORD=${ROOT_PASSWORD:-password}
WEBMIN_ENABLED=${WEBMIN_ENABLED:-true}
WEBMIN_INIT_SSL_ENABLED=${WEBMIN_INIT_SSL_ENABLED:-true}
WEBMIN_INIT_REDIRECT_PORT=${WEBMIN_INIT_REDIRECT_PORT:-10000}
WEBMIN_INIT_REFERERS=${WEBMIN_INIT_REFERERS:-NONE}

BIND_DATA_DIR=${DATA_DIR}/bind
BIND_ENABLED=${BIND_ENABLED:-true}
BIND_EXIT_CODE=0

DHCPD_DATA_DIR=${DATA_DIR}/dhcpd
DHCPD_ENABLED=${DHCPD_ENABLED:-true}
DHCPD_PROTOCOL=${DHCPD_PROTOCOL:-4}
DHCPD_DEFAULT="$DHCPD_DATA_DIR/dhcpdDefaultEnv.sh"
DHCPD_EXIT_CODE=0

SERVER_FQDN=$(hostname --fqdn 2>/dev/null || echo "$(hostname -s).local")
APACHE_SERVER_NAME=${APACHE_SERVER_NAME:-$SERVER_FQDN}
APACHE_DATA_DIR=${DATA_DIR}/httpd
APACHE_WWW_DIR=${APACHE_WWW_DIR:-/var/www}
APACHE_ENABLED=${APACHE_ENABLED:-true}
APACHE_EXIT_CODE=0


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
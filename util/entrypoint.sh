#!/bin/bash

set -e

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

echo "Variables done..."

# Check arguments
is_network_interface() {
    # skip wait-for-interface behavior if found in path
    if ! which "$1" > /dev/null 2>&1; then
        # loop until interface is found, or we give up
        NEXT_WAIT_TIME=1
        until [ -e "/sys/class/net/$1" ] || [ $NEXT_WAIT_TIME -eq 4 ]; do
            sleep $(( NEXT_WAIT_TIME++ ))
            echo "Waiting for interface '$1' to become available... ${NEXT_WAIT_TIME}"
        done
        if [ -e "/sys/class/net/$1" ]; then
            return 0
        fi
    fi
    return 1
}
NETW_IFACES=""
while (( $# )); do
  case $1 in
  '--no-dns') BIND_ENABLED=false;;
  '--no-dhcp') DHCPD_ENABLED=false;;
  '--no-httpd') APACHE_ENABLED=false;;
  *) if is_network_interface $1; then
       # Prevent the leading space
       if [ -z "$NETW_IFACES" ]; then
         NETW_IFACES="$1"
       else
         NETW_IFACES="$NETW_IFACES $1"
       fi
     else
       echo "Warning: network interface $1 not found"
     fi
  esac
  shift
done

## ----- webmin -----
create_webmin_data_dir() {
  mkdir -p ${WEBMIN_DATA_DIR}
  chmod -R 0755 ${WEBMIN_DATA_DIR}
  chown -R root:root ${WEBMIN_DATA_DIR}

  # populate the default webmin configuration if it does not exist
  if [ ! -d ${WEBMIN_DATA_DIR}/etc ]; then
    mv /etc/webmin ${WEBMIN_DATA_DIR}/etc
  fi
  rm -rf /etc/webmin
  ln -sf ${WEBMIN_DATA_DIR}/etc /etc/webmin
  
  # Add the DHCPd config dir for webmin
  mkdir -p ${WEBMIN_DATA_DIR}/dhcpd
  chmod -R 0755 ${WEBMIN_DATA_DIR}/dhcpd
  chown -R root:root ${WEBMIN_DATA_DIR}/dhcpd
}

disable_webmin_ssl() {
  sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
}

set_webmin_config() {
  echo "redirect_port=$WEBMIN_INIT_REDIRECT_PORT" >> /etc/webmin/miniserv.conf
  echo "dhcpd_conf=$DHCPD_DATA_DIR/dhcpd.conf" >> /etc/webmin/dhcpd/config
  echo "lease_file=$DHCPD_DATA_DIR/dhcpd.leases" >> /etc/webmin/dhcpd/config
  echo "pid_file=/var/run/dhcpd/dhcpd.pid" >> /etc/webmin/dhcpd/config
  echo "start_cmd=/etc/init.d/isc-dhcp-server start" >> /etc/webmin/dhcpd/config
  echo "stop_cmd=/etc/init.d/isc-dhcp-server stop" >> /etc/webmin/dhcpd/config
  echo "restart_cmd=/etc/init.d/isc-dhcp-server restart" >> /etc/webmin/dhcpd/config
}

set_webmin_referers() {
  echo "referers=$WEBMIN_INIT_REFERERS" >> /etc/webmin/config
}

set_root_passwd() {
  echo "root:$ROOT_PASSWORD" | chpasswd
}

first_init() {
  if [ ! -f /data/.initialized ]; then
    set_webmin_config
    if [ "${WEBMIN_INIT_SSL_ENABLED}" == "false" ]; then
      disable_webmin_ssl
    fi
    if [ "${WEBMIN_INIT_REFERERS}" != "NONE" ]; then
      set_webmin_referers
    fi
    touch /data/.initialized
  fi
}

## ----- httpd apache2 -----
change_httpd_user_group_id () {
    uid=$(stat -c%u "$APACHE_WWW_DIR")
    gid=$(stat -c%g "$APACHE_WWW_DIR")
    if [ $gid -ne 0 ]; then
        groupmod -g $gid www-data
    fi
    if [ $uid -ne 0 ]; then
        usermod -u $uid www-data
    fi
}

create_httpd_data_dir() {
  mkdir -p ${APACHE_DATA_DIR}
  chmod -R 0755 ${APACHE_DATA_DIR}
  # populate default apache2 configuration if it does not exist
  if [ ! -d ${APACHE_DATA_DIR}/etc ]; then
    mv /etc/apache2 ${APACHE_DATA_DIR}/etc
  fi
  rm -rf /etc/apache2
  ln -sf ${APACHE_DATA_DIR}/etc /etc/apache2

  if [ ! -d ${APACHE_DATA_DIR}/lib ]; then
    mv /var/lib/apache2 ${APACHE_DATA_DIR}/lib
  fi
  rm -rf /var/lib/apache2
  ln -sf ${APACHE_DATA_DIR}/lib /var/lib/apache2
}

insert_htppd_ServerName() {
  egrep -q '^ServerName ' /etc/apache2/apache2.conf > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    sed -i "s/# Global configuration/# Global configuration\nServerName \"$APACHE_SERVER_NAME\"/"  /etc/apache2/apache2.conf
  else
    sed -i "s/^ServerName.*$/ServerName \"$APACHE_SERVER_NAME\"/"  /etc/apache2/apache2.conf
  fi
}

if [ "$APACHE_ENABLED" == "true" ]; then
  change_httpd_user_group_id
  create_httpd_data_dir
  insert_htppd_ServerName
  echo "Starting httpd (apache2)..."
  /etc/init.d/apache2 start
  APACHE_EXIT_CODE=$?
fi

## ----- DNS bind -----

create_bind_data_dir() {
  mkdir -p ${BIND_DATA_DIR}

  # populate default bind configuration if it does not exist
  if [ ! -d ${BIND_DATA_DIR}/etc ]; then
    mv /etc/bind ${BIND_DATA_DIR}/etc
  fi
  rm -rf /etc/bind
  ln -sf ${BIND_DATA_DIR}/etc /etc/bind
  chmod -R 0775 ${BIND_DATA_DIR}
  chown -R ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}

  if [ ! -d ${BIND_DATA_DIR}/lib ]; then
    mkdir -p ${BIND_DATA_DIR}/lib
    chown ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}/lib
  fi
  rm -rf /var/lib/bind
  ln -sf ${BIND_DATA_DIR}/lib /var/lib/bind
}

create_bind_pid_dir() {
  mkdir -p /var/run/named
  chmod 0775 /var/run/named
  chown root:${BIND_USER} /var/run/named
}

create_bind_cache_dir() {
  mkdir -p /var/cache/bind
  chmod 0775 /var/cache/bind
  chown root:${BIND_USER} /var/cache/bind
}

  create_bind_pid_dir
  create_bind_data_dir
  create_bind_cache_dir
if [ "$BIND_ENABLED" == "true" ]; then
  echo "Starting named..."
  "$(command -v named)" -u ${BIND_USER}
  BIND_EXIT_CODE=$?
fi

## ----- DHCPd -----

create_dhcp_dirs () {
    # Create dirs
    mkdir -p ${DHCPD_DATA_DIR}
    mkdir -p /var/run/dhcpd/
}

create_default_dhcp_env_file () {
    # Build a default DHCPd environment (for isc-dhcp-server start)
    echo "OPTIONS=-$DHCPD_PROTOCOL" > $DHCPD_DEFAULT
    echo "DHCPD_PID=/var/run/dhcpd/dhcpd.pid" >> $DHCPD_DEFAULT
    echo "DHCPD_CONF=$DHCPD_DATA_DIR/dhcpd.conf"  >> $DHCPD_DEFAULT
    echo "DHCPD_LEASES=$DHCPD_DATA_DIR/dhcpd.leases" >> $DHCPD_DEFAULT
    echo "INTERFACES=\"$NETW_IFACES\"" >> $DHCPD_DEFAULT
    chown dhcpd:dhcpd $DHCPD_DEFAULT
    chmod 755 $DHCPD_DEFAULT
}

#remove_stale_pid_file () {
#    # Check for pid file, remove if it exists
#    if [ -f "$DHCPD_DATA_DIR/run/dhcpd.pid" ]; then
#      rm -f "$DHCPD_DATA_DIR/run/dhcpd.pid"
#    fi
#}

create_dummy_dhcp_config () {
    BCAST=$(ip -4 addr show $1 | grep -Po 'brd \K[\d.]+')
    NETAD=$(echo $BCAST | grep -Po '\d+\.\d+\.\d+')
    echo "option domain-name \"dummy.lan\";" > $dhcpd_conf
    echo "option broadcast-address $BCAST;" >> $dhcpd_conf
    echo "subnet $NETAD.0 netmask 255.255.255.0 { host dummy { } range $NETAD.10 $NETAD.100; }" >> $dhcpd_conf
    chown dhcpd:dhcpd $dhcpd_conf
}

touch_leases_file () {
    [ -e "$DHCPD_DATA_DIR/dhcpd.leases" ] || touch "$DHCPD_DATA_DIR/dhcpd.leases"
    chown dhcpd:dhcpd "$DHCPD_DATA_DIR/dhcpd.leases"
    if [ -e "$DHCPD_DATA_DIR/dhcpd.leases~" ]; then
        chown dhcpd:dhcpd "$DHCPD_DATA_DIR/dhcpd.leases~"
    fi
}

change_dhcp_user_group_id () {
    uid=$(stat -c%u "$DHCPD_DATA_DIR")
    gid=$(stat -c%g "$DHCPD_DATA_DIR")
    if [ $gid -ne 0 ]; then
        groupmod -g $gid dhcpd
    fi
    if [ $uid -ne 0 ]; then
        usermod -u $uid dhcpd
    fi
}

create_dhcp_dirs
change_dhcp_user_group_id
create_default_dhcp_env_file
touch_leases_file
# remove_stale_pid_file

if [ "$DHCPD_ENABLED" == "true" ]; then
  echo "DHCPd bind interfaces: $NETW_IFACES"

  dhcpd_conf="${DHCPD_DATA_DIR}/dhcpd.conf"
  # Check if dhcpd.conf exists, build a dummy one if not
  if [ ! -f "$dhcpd_conf" ]; then
    if [ -z "$NETW_IFACES" ]; then
      echo "Warning: 1st time exec of DHCPd requires at least one network interface: none given."
      echo "DHCPd not started."
    else
      # Get the first interface and use it to build the dummy config
      IFACE=$(echo $NETW_IFACES | cut -d " " -f1)
      create_dummy_dhcp_config $IFACE
    fi
  fi
  
  grep -iq "subnet" ${DHCPD_DATA_DIR}/dhcpd.conf > /dev/null 2>&1 && /etc/init.d/isc-dhcp-server start
  DHCPD_EXIT_CODE=$?
fi

## ----- Check exit codes and start webmin -----

[ $BIND_EXIT_CODE -ne 0 ] && echo "Warning: Failed to start DNS (bind). Exit code $BIND_EXIT_CODE"
[ $DHCPD_EXIT_CODE -ne 0 ] && echo "Warning: Failed to start DHCPd. Exit code $DHCPD_EXIT_CODE"
[ $APACHE_EXIT_CODE -ne 0 ] && echo "Warning: Failed to start httpd (apache2). Exit code $APACHE_EXIT_CODE"
if [ "${WEBMIN_ENABLED}" == "true" ]; then
  create_webmin_data_dir
  #disable_webmin_ssl
  first_init
  set_root_passwd
  echo "Starting webmin..."
  exec /etc/webmin/start
else
  sleep infinity
fi

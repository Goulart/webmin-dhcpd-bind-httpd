# Missing:
# 
# APACHE_HTTPS_PORT to APACHE_LOGLEVEL are useless: 
#                   not being transfered to httpd configuration!!

FROM ubuntu:xenial-20210114

# apt-get options for silent installations
ENV APT_OPTIONS='-y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef"'

# Define sources lists
RUN echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list

# Get GPG public keys
COPY pgpKeys/jcameron-key.asc /jcameron-key.asc
RUN apt-key add /jcameron-key.asc && rm -f /jcameron-key.asc

# Update Ubuntu
RUN apt-get $APT_OPTIONS update

ENV ROOT_PASSWORD=password                        \
    WEBMIN_ENABLED=true                           \
    WEBMIN_INIT_SSL_ENABLED=true                  \
    WEBMIN_INIT_REDIRECT_PORT=10000               \
    WEBMIN_INIT_REFERERS=NONE                     \
    BIND_USER=bind                                \
    BIND_VERSION=9.10.3                           \
    APACHE_VERSION=2.4.18                         \
    WEBMIN_VERSION=1.970                          \
    DHCPD_VERSION=4.3.3                           \
    DHCPD_PROTOCOL=4                              \
    APACHE_SERVER_NAME=                           \
    APACHE_HTTPS_PORT=                            \
    APACHE_HTTP_PORT=                             \
    APACHE_LOCK_DIR=/var/lock/apache2             \
    APACHE_RUN_DIR=/var/run/apache2               \
    APACHE_PID_FILE=${APACHE_RUN_DIR}/apache2.pid \
    APACHE_LOG_DIR=/var/log/apache2               \
    APACHE_RUN_USER=www-data                      \
    APACHE_RUN_GROUP=www-data                     \
    APACHE_MAX_REQUEST_WORKERS=32                 \
    APACHE_MAX_CONNECTIONS_PER_CHILD=1024         \
    APACHE_ALLOW_OVERRIDE=None                    \
    APACHE_ALLOW_ENCODED_SLASHES=Off              \
    APACHE_ERRORLOG=""                            \
    APACHE_CUSTOMLOG=""                           \
    APACHE_LOGLEVEL=error                         \
    APACHE_WWW_DIR=/var/www                       \
    DATA_DIR=/data

RUN rm -rf /etc/apt/apt.conf.d/docker-gzip-indexes \
    && apt-get $APT_OPTIONS install apt-utils dnsutils man-db \
               bind9=1:${BIND_VERSION}* \
               bind9-host=1:${BIND_VERSION}* \
               isc-dhcp-server=${DHCPD_VERSION}* \
               apache2=${APACHE_VERSION}* \
               webmin=${WEBMIN_VERSION}* \
    && sed -i "s|^DHCPD_DEFAULT=.*$|DHCPD_DEFAULT=$DATA_DIR/dhcpd/dhcpdDefaultEnv.sh|" /etc/init.d/isc-dhcp-server \
    && sed -i 's/\-q $OPTIONS/$OPTIONS/' /etc/init.d/isc-dhcp-server \
    && sed -i "s|^exec '/usr/share/webmin/miniserv.pl'|exec '/usr/share/webmin/miniserv.pl' --nofork|" /etc/webmin/start \
    && apt-get -y autoremove \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 53/udp 53/tcp 67/udp 68/udp 67/tcp 68/tcp 80/tcp 443/tcp 10000/tcp

COPY util/entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
#CMD ["/etc/webmin/start"]
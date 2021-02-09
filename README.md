## webmin-dhcpd-bind-httpd

HTTPD (apache2), ISC (https://kb.isc.org/) DNS (bind9) and DHCP servers in the same container. \
Managed under webmin (https://www.webmin.com)

Based on ubuntu:xenial-20210114 and the excellent work of:
  - sameersbn/bind
  - networkboot/dhcpd

This seems a bloated, wrong way to conceive a container, but it was
born from the need to have all three servers under webmin, correcting as
needed, and benefitting from other webmin goodies,
  - configuration control for all servers
  - start and stop servers;
  - log and other file views;
  - direct commands to bash;
  - file editing;
  - etc

The (unforked) main process is the webmin server.
If you want to stop the container, just stop the webmin server.

### Example preparation

**apache**
  - create a directory, e.g. `/srv/www`
  - create a user and group `www-data`
  - set the owner: `chown www-data:www-data /srv/www`

**dhcpd** [optional]
  - define the interface for DHCPd, say `eth0`
  - create a directory for DHCPd data, `/etc/docker/dhcpd`
  - create a valid `/etc/docker/dhcpd/dhcpd.conf` file for the interface

**bind** ... nothing to do

### Execution
Start: \
  docker  run  ***[options]***  ***[volumes]***  ***[portmaps]***  goulart/webmin-dhcpd-bind-httpd:1.0 [***netwkInterfaces***]  [--no-dns]  [--no-dhcp]  [--no-httpd]

Start examples: \
  `docker run -t --rm --net host -v /etc/docker:/data:Z -v /srv/www:/var/www:Z -e APACHE_SERVER_NAME="www.local.lan" goulart/webmin-dhcpd-bind-httpd:1.0 eth0` \
(`eth0` is the adapter the DHCPd will bind to)

  `docker run -d --rm -p 53:53/tcp -p 53:53/udp -p 10000:10000/tcp -p 8080:80 -v /etc/docker:/data:Z -v /srv/www:/var/www:Z goulart/webmin-dhcpd-bind-httpd:1.0 --no-dhcp` \
(Start bind, httpd and webmin)

[***netwkInterfaces***] (dhcp only)
  - More than one network interface may be specified for dhcpd
  - If none given, dhcpd listens on all interfaces
  - If starting dhcpd always use `--net host` (broadcasting does not bridge)

[--no-dns]
  - Do not start bind9 (DNS server)

[--no-dhcp]
  - Do not start DHCP server

[--no-httpd]
  - Do not start httpd (apache2)

Webmin:
  * point browser to https://***[host]***:10000
  * username: `root`
  * password: `password`

Ports:
  * DNS server (bind9):
    * 53/udp
    * 53/tcp
  * DHCP server:
    * 67/udp
    * 68/udp
    * 67/tcp
    * 68/tcp
  * HTTPD (apache2) server:
    * 80/tcp
    * 443/tcp
  * webmin:
    * 10000/tcp

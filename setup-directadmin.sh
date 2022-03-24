#!/bin/bash

if [ -z "$1" ]
  then
    echo "No license key given."
	exit 0;
fi

# First install and configure the server as a normal install.
chmod 777 ./standard-settings.sh
./standard-settings.sh

# Run Common pre-install commands
apt -y update
apt -y upgrade
apt -y install gcc g++ make flex bison openssl libssl-dev perl perl-base perl-modules libperl-dev libperl4-corelibs-perl libwww-perl libaio1 libaio-dev zlib1g zlib1g-dev libcap-dev cron bzip2 zip automake autoconf libtool cmake pkg-config python libdb-dev libsasl2-dev libncurses5 libncurses5-dev libsystemd-dev bind9 dnsutils quota patch logrotate rsyslog libc6-dev libexpat1-dev libcrypt-openssl-rsa-perl libnuma-dev libnuma1

# Collect some required info.
serverip=`hostname -I | awk '{print $1}'`
serverhostname=`dig -x ${serverip} +short | sed 's/\.[^.]*$//'`
domainhostname=`echo $serverhostname | sed 's/^[^.]*.//g'`
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

# Set some variables to let DirectAdmin install correctly.
export DA_CHANNEL=current
export DA_HOSTNAME=$serverhostname
export DA_NS1=$ns1host
export DA_NS2=$ns2host
export DA_FOREGROUND_CUSTOMBUILD=yes

# Download and run the DirectAdmin install script.
wget -O install.sh https://download.directadmin.com/setup.sh
chmod 755 install.sh
./install.sh $1

# Enable and build cURL in CustomBuilds.
cd /usr/local/directadmin/custombuild
sed -i "s/curl=no/curl=yes/g" options.conf
./build curl

# Download and install sftp scripts by poralix for ssh backup support.
cd /usr/local/directadmin/scripts/custom/
wget -O ssh_script.zip https://github.com/poralix/directadmin-sftp-backups/archive/refs/heads/master.zip
unzip ssh_script.zip
cd directadmin-sftp-backups-master/
mv ftp_*.php ./../
cd ..
rm -rf directadmin-sftp-backups-master/
rm ssh_script.zip

# Enable and build LetsEncrypt.
cd /usr/local/directadmin/custombuild
./build rewrite_confs
./build update
./build letsencrypt

# Request LetsEncrypt Certificates for the directadmin domain itself.
/usr/local/directadmin/scripts/letsencrypt.sh request_single $serverhostname 4096
/usr/local/directadmin/directadmin set ssl_redirect_host $serverhostname
service directadmin restart

# Enable multi SSL support for the mail server.
echo "mail_sni=1" >> /usr/local/directadmin/conf/directadmin.conf
service directadmin restart
cd /usr/local/directadmin/custombuild
./build clean
./build update
./build set eximconf yes
./build set dovecot_conf yes
./build exim_conf
./build dovecot_conf
echo "action=rewrite&value=mail_sni" >> /usr/local/directadmin/data/task.queue

clear
. /usr/local/directadmin/scripts/setup.txt
echo "Username: $adminname"
echo "Password: $adminpass"
echo "Domain: $serverhostname"


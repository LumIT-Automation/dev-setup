#!/bin/bash

set -e

function System()
{
    base=$FUNCNAME
    this=$1

    # Declare methods.
    for method in $(compgen -A function)
    do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done

    # Properties list.
    ACTION="$ACTION"
    PROXY="$PROXY"

    DATABASE_USER_PASSWORD="password"
    SYSTEM_USERS_PASSWORD="Password01!"
}

# ##################################################################################################################################################
# Public
# ##################################################################################################################################################

#
# Void System_run().
#
function System_run()
{
    if [ "$ACTION" == "install" ]; then
        if System_checkEnvironment; then
            printf "\n* Installing system dependencies...\n"
            echo "This script requires a fresh-installation of Debian Buster..."

            System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
            System_sshConfig
            System_proxySet "$PROXY"
            System_installDependencies
            System_pythonSetup
            System_syslogngInstall
            System_mariadbSetup "$DATABASE_USER_PASSWORD"
            System_apacheSetup "$SYSTEM_USERS_PASSWORD" "$DATABASE_USER_PASSWORD"
            System_mariadbRestore
            System_consulAgentInstall
            System_redisSetup
            System_towerCliInstall
            System_squidSetup
            System_lumitVpnSupplicantSetup
            System_pipInstallDaemon_api
            System_celeryStart
        else
            echo "A Debian Buster operating system is required for the installation. Aborting."
            exit 1
        fi
    else
        exit 1
    fi
}

# ##################################################################################################################################################
# Private static
# ##################################################################################################################################################

function System_checkEnvironment()
{
    if [ -f /etc/os-release ]; then
        if ! grep -q 'Debian GNU/Linux 10 (buster)' /etc/os-release; then
            return 1
        fi
    else
        return 1
    fi

    return 0
}



function System_rootPasswordConfig()
{
    printf "\n* Setting a password for root [Vagrant installation]...\n"

    printf "$1\n$1" | passwd
}



function System_sshConfig()
{
    printf "\n* Enabling SSH with password auth [Vagrant installation]...\n"

    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    systemctl restart ssh
}



function System_proxySet()
{
    printf "\n* Setting up system proxy...\n"

    if ! grep -qi "http_proxy" /etc/environment; then
        echo "http_proxy=$1" >> /etc/environment
        echo "https_proxy=$1" >> /etc/environment
    else
        sed -i "s|http_proxy=.*|http_proxy=$1|g" /etc/environment
        sed -i "s|https_proxy=.*|https_proxy=$1|g" /etc/environment
    fi

    export http_proxy=$1
    export https_proxy=$1
}



function System_installDependencies()
{
    printf "\n* Preparing the environment: removing the cdrom entry in apt/sources.list, if present...\n"
    printf "\n* Installing system dependencies...\n"
	
    systemctl stop openconnect_vpn >/dev/null 2>&1 || true

    if [ -r /tmp/sources.list ]; then
        cp -f /tmp/sources.list /etc/apt/sources.list
    fi

    apt update

cat > /tmp/grub-pc.selections<<EOF
grub-pc grub2/kfreebsd_cmdline_default string quiet
grub-pc grub-pc/timeout string 1
grub-pc grub2/force_efi_extra_removable boolean false
grub-pc grub-pc/install_devices string /dev/vda
grub-pc grub-pc/disk_description string
grub-pc grub-pc/install_devices_failed_upgrade boolean true
grub-pc grub-pc/postrm_purge_boot_grub boolean false
grub-pc grub2/linux_cmdline string
grub-pc grub2/kfreebsd_cmdline string
grub-pc grub-pc/install_devices_disks_changed boolean
grub-pc grub-pc/chainload_from_menu.lst boolean true
grub-pc grub-pc/install_devices_empty boolean false
grub-pc grub-pc/hidden_timeout boolean false
grub-pc grub2/update_nvram boolean true
grub-pc grub-pc/kopt_extracted boolean false
grub-pc grub-pc/partition_description string
grub-pc grub-pc/mixed_legacy_and_grub2 boolean true
grub-pc grub2/linux_cmdline_default string "console=tty0 console=tty1 console=ttyS0,38400n8"
grub-pc grub-pc/install_devices_failed boolean false
EOF

    debconf-set-selections /tmp/grub-pc.selections
    
    #apt-mark hold grub-pc grub-pc-bin
    #DEBIAN_FRONTEND=noninteractive apt -y upgrade    

    apt install -y wget git unzip net-tools dnsutils dos2unix curl # base.
    apt install -y openfortivpn # lumit VPN specific.
    apt install -y openconnect
    apt install -y python3-pip python3-dev # base python + dev.
    apt install -y python3-venv # for making the .deb.
    apt install -y mariadb-server libmariadb-dev # mariadb server + dev (for the mysqlclient pip package).
    apt install -y php7.3-mysql php7.3-mbstring # php and php for mysql.
    apt install -y libapache2-mod-php7.3 libapache2-mod-wsgi-py3 # apache for php and python.
    apt install -y redis-server # redis.
    apt install -y rpm # for building rh packages.

    apt clean
}



function System_pythonSetup()
{
    printf "\n* Installing pip dependencies for Django, plus for tower-cli...\n"
	
    systemctl stop openconnect_vpn >/dev/null 2>&1 || true

    update-alternatives --install /usr/bin/python python /usr/bin/python3.7 1
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1 # best practice for simply creating a sumlink.

    # pip Requirements files are used to hold the result from pip freeze for the purpose of achieving repeatable installations.
    # In this case, your requirement file contains a pinned version of everything that was installed when pip freeze was run.
    # pip freeze > requirements.txt
    # pip install -r requirements.txt

    # Requirement Specifiers
    # SomeProject
    # SomeProject == 1.3
    # SomeProject >=1.2,<2.0
    # SomeProject[foo, bar]
    # SomeProject~=1.4.2

    pip install --upgrade pip
    pip install -r /var/www/api/api/pip.requirements # pip install requirements.
}



function System_mariadbSetup()
{
    printf "\n* Setting up MariaDB: user api...\n"

    databaseUserPassword=$1

    # Enable general log and log error via syslog.
    cp -f /vagrant/api-cisconx/etc/mysql/mariadb.conf.d/51-mariadb.cnf /etc/mysql/mariadb.conf.d
    cp -f /vagrant/api-cisconx/etc/mysql/mariadb.conf.d/99-log.cnf /etc/mysql/mariadb.conf.d
    chmod 644 /etc/mysql/mariadb.conf.d/*cnf

    # by default /etc/systemd/system/mysql.service and mysqld.service are symlink to /lib/systemd/system/mariadb.service.
    sed -i -r -e '/^\[Service\]$/a StandardOutput=syslog\nStandardError=syslog\nSyslogFacility=daemon\nSyslogLevel=warning\nSyslogIdentifier=mysql' /etc/systemd/system/mysql.service # this one replaces the symlink with a new file.
    chmod 644 /etc/systemd/system/mysql.service
    rm -f /etc/systemd/system/mysqld.service
    ln -s /etc/systemd/system/mysql.service /etc/systemd/system/mysqld.service
    ln -s /etc/systemd/system/mysql.service /etc/systemd/system/mariadb.service

    systemctl daemon-reload
    systemctl restart mysql

    if mysql -e "exit" >/dev/null 2>&1; then
        if [ "$(mysql --vertical -e "SELECT User FROM mysql.user WHERE User = 'api';" | tail -1 | awk '{print $2}')" == "" ]; then
            # User api not present: create.
            mysql -e "CREATE USER 'api'@'localhost' IDENTIFIED BY '$databaseUserPassword';"
        else
            # Update user's password.
            mysql -e "SET PASSWORD FOR 'api'@'localhost' = PASSWORD('$databaseUserPassword');"
        fi
    else
        echo "MariaDB error: shell access disabled."
        exit 1
    fi
}



function System_squidSetup()
{
    printf "\n* Setting up Squid proxy server: ...\n"

    apt install squid -y

    if [ ! -f /etc/squid/squid.conf.orig ]; then
        cp /etc/squid/squid.conf /etc/squid/squid.conf.orig
    fi

    # To allow connections from host PC to destination.
    if ! grep -q hostnet /etc/squid/squid.conf; then
        sed -i '/acl CONNECT method CONNECT/a \\nacl hostnet src 10.0.111.0\/24' /etc/squid/squid.conf
        sed -i '/# Deny CONNECT to other than.*/i http_access allow hostnet CONNECT' /etc/squid/squid.conf
        sed -i '/http_access allow localhost/a http_access allow hostnet' /etc/squid/squid.conf
    fi

    systemctl restart squid
}



function System_apacheSetup()
{
    printf "\n* Setting up Apache...\n"

    cd /tmp

    # /var/www/api is mounted by Vagrant (share), here lays the Django stub project.
    if [ ! -d /var/www/api ]; then
        echo "/var/www/api does not exist, check your Vagrant setup."
        exit 1
    fi

    #chown -R www-data:www-data /var/www/mysite # unneeded since Vagrant's mounting.

    # Copy phpMyAdmin files.
    if [ ! -f phpMyAdmin-5.0.2-all-languages.zip ]; then
        wget https://files.phpmyadmin.net/phpMyAdmin/5.0.2/phpMyAdmin-5.0.2-all-languages.zip
    fi

    unzip phpMyAdmin-5.0.2-all-languages.zip >/dev/null

    if [ -d /var/www/myadmin ]; then
        if [ -d /tmp/myadmin ]; then
            rm -Rf /tmp/myadmin
        fi
        mv /var/www/myadmin /tmp/myadmin

        echo "I've found a /var/www/myadmin folder, which I moved to /tmp/."
    fi
    mv phpMyAdmin-5.0.2-all-languages /var/www/myadmin
    chown -R www-data:www-data /var/www/myadmin

    # Configure phpMyAdmin for direct login.
    # Configure phpMyAdmin for direct login.
    sed -i "s/\$cfg\['Servers'\]\[\$i\]\['auth_type'\].*/\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'config';/g" /var/www/myadmin/libraries/config.default.php
    sed -i "s/\$cfg\['Servers'\]\[\$i\]\['user'\].*/\$cfg\['Servers'\]\[\$i\]\['user'\] = 'api';/g" /var/www/myadmin/libraries/config.default.php
    sed -i "s/\$cfg\['Servers'\]\[\$i\]\['password'\].*/\$cfg\['Servers'\]\[\$i\]\['password'\] = '$2';/g" /var/www/myadmin/libraries/config.default.php

    # Create proxy.pac.
    # This particular VPN is full-tunnel, so we need a way to browse to their AWX with our host's browser.
    if [ -d /var/www/proxypac ]; then
        if [ -d /tmp/proxypac ]; then
            rm -Rf /tmp/proxypac
        fi
        mv /var/www/proxypac /tmp/proxypac

        echo "I've found a /var/www/proxypac folder, which I moved to /tmp/."
    fi
	
    mkdir /var/www/proxypac

    cat >/var/www/proxypac/proxy.pac<<EOF
function FindProxyForURL(url, host)
{
    host = host.toLowerCase();
    if (dnsDomainIs(host, "VPN_DOMAIN") || isInNet(host, '10.0.252.0', '255.255.255.0')) #@todo: change for the case.
        return "PROXY 10.0.111.20:3128"; // (IP:port)

    return "DIRECT";
}
EOF

    # Setup the Django project virtual host.
    # Static content has been moved from rest_framework to static/ via the use of python manage.py collectstatic.
    cp -f /vagrant/api-cisconx/etc/apache2/sites-available/001-django.conf /etc/apache2/sites-available/001-django.conf
    chmod 644 /etc/apache2/sites-available/001-django.conf

    # Setup the phpMyAdmin virtual host on port 8300.
    cp -f /vagrant/api-cisconx/etc/apache2/sites-available/001-mysql.conf /etc/apache2/sites-available/001-mysql.conf
    chmod 644 /etc/apache2/sites-available/001-mysql.conf

    # Setup the virtual host on port 8200 for serving the proxy.pac.
    cat > /etc/apache2/sites-available/001-proxypac.conf<<EOF
<VirtualHost *:8200>
    ServerName proxypac
    ServerAdmin ing.marcoburatto@gmail.com

    DocumentRoot /var/www/proxypac
    <Directory /var/www/proxypac>
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    # This is a trick in order for Apache not to need to be reloaded at every .py modification.
    if ! grep -q "MaxRequestsPerChild" /etc/apache2/apache2.conf; then
        printf "\nMaxRequestsPerChild 1\n" >> /etc/apache2/apache2.conf
    fi

    # Give www-data access to the shell and set a password; used for sshfs and ssh access.
    usermod --shell /bin/bash www-data
    printf "$1\n$1" | passwd www-data

    # Force enabling the wsgi module.
    a2enmod wsgi

    a2query -s 000-default && a2dissite 000-default # disable default Apache site, only if enabled.
    
    if ! grep -q '^Listen 8200$' /etc/apache2/ports.conf; then
        echo "Listen 8200" >> /etc/apache2/ports.conf
    fi
    
    if ! grep -q '^Listen 8300$' /etc/apache2/ports.conf; then
        echo "Listen 8300" >> /etc/apache2/ports.conf
    fi        

    # Setup Apache config files for its virtualhosts.
    a2ensite 001-django
    a2ensite 001-mysql
    a2ensite 001-proxypac
    a2query -s 000-default && a2dissite 000-default # disable default site, only if enabled.

    systemctl restart apache2
}



System_mariadbRestore()
{
    printf "\n* Restoring the database from its SQL dump...\n"

    #mysql -e 'DROP DATABASE IF EXISTS `api`;'
    #mysql -e 'CREATE DATABASE `api` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
    #mysql -e "GRANT USAGE ON *.* TO 'api'@'localhost' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;"
    #mysql -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, ALTER, CREATE TEMPORARY TABLES, CREATE VIEW, SHOW VIEW, EXECUTE ON `api`.* TO `api`@`localhost`;'

    #mysql api < /var/www/api/awx/sql/dump.sql
}



System_towerCliInstall()
{
    printf "\n* Installing AWX; ansible from Buster-backports...\n"

    # Installed by pip.
#    cat >/etc/apt/sources.list.d/buster-backports.list<<EOF
#deb http://deb.debian.org/debian/ buster-backports main contrib
#deb-src http://deb.debian.org/debian/ buster-backports main contrib
#EOF

    # apt update
    # apt -t buster-backports -y install ansible
    # apt clean

    # Setup tower-cli, for both root and www-data.
    chmod 400 /var/www/api/api/tower_cli.cfg
    ln -s /var/www/api/api/tower_cli.cfg /root/.tower_cli.cfg
    ln -s /var/www/api/api/tower_cli.cfg /var/www/.tower_cli.cfg
}



System_consulAgentInstall()
{
    printf "\n* Setting up the Consul agent...\n"

    # Install Consul.
    apt install -y consul

    # Expose Consul api service.
    cp -f /vagrant/api-cisconx/etc/consul.d/api.json /etc/consul.d/api.json
    chmod 644 /etc/consul.d/api.json

    # Setup a Systemd Consul service unit.
    # Consul will bind to the source IP address which has route to Consul server agent.
    cp -f /vagrant/api-cisconx/usr/bin/consul.sh /usr/bin/consul.sh
    chmod 755 /usr/bin/consul.sh

    cp -f /vagrant/api-cisconx/etc/systemd/system/consul.service /etc/systemd/system/consul.service
    chmod 644 /etc/systemd/system/consul.service

    systemctl daemon-reload
    systemctl enable consul
    systemctl restart consul
}



System_syslogngInstall()
{
    apt install -y syslog-ng

    # Fix the syslog-ng main file. Needed to avoid logging also in /var/log/syslog.
    # Move the inclusion of the conf.d files before the log path entries if needed.
    cd /etc/syslog-ng/
    if grep -Eq '[iI]nclude.*/etc/syslog-ng/conf.d/' syslog-ng.conf; then
        # Backup the main config file.
        cp syslog-ng.conf "syslog-ng.conf.`date +%Y%m%d.%H%M`"

        # Cleanup the current include directive.
        sed -i -r -e '/[iI]nclude.*\/etc\/syslog-ng\/conf.d\//d' syslog-ng.conf
        sed -i -r '${/^#+/d;}' syslog-ng.conf
        sed -i -r '${/^#+/d;}' syslog-ng.conf

        # Add the include directive in the right place.
        sed -i -e '/# Log paths/i # Include all config files in \/etc\/syslog-ng\/conf.d\/\n########################\n@include "\/etc\/syslog-ng\/conf.d\/*.conf"\n\n\n########################' syslog-ng.conf
    fi

    # Add syslog.host entry in /etc/hosts (remote logger).
    serverAddress="10.0.111.253"
    sed -i '/syslog.host/d' /etc/hosts
    echo "$serverAddress        syslog.host" >> /etc/hosts

    # syslog-ng config files.
    cp -f /vagrant/api-cisconx/etc/syslog-ng/conf.d/*conf /etc/syslog-ng/conf.d/
    chmod 644 /etc/syslog-ng/conf.d/*conf

    mkdir -p /var/log/automation
    systemctl restart syslog-ng
}



System_lumitVpnSupplicantSetup()
{
    printf "\n* Setting up Systemd service for LumIT VPN...\n"

    if [ -f /tmp/.vpn.env ]; then
        # Openfortivpn config.
        mkdir -p /etc/openfortivpn
        mv /tmp/.vpn.env /etc/openfortivpn/config
        chmod 400 /etc/openfortivpn/config

        sed -i 's/lumit_vpn_//g' /etc/openfortivpn/config
        sed -i 's/trusted_cert/trusted-cert/g' /etc/openfortivpn/config
        sed -i '/openconnect_vpn/d' /etc/openfortivpn/config

        # Systemd VPN service.
        cp -f /vagrant/api-infoblox/etc/systemd/system/lumitvpn.service /etc/systemd/system/lumitvpn.service
        chmod 644 /etc/systemd/system/lumitvpn.service

        cp -f /vagrant/api-infoblox/sbin/lumitvpn.sh /sbin/lumitvpn.sh
        chmod 755 /sbin/lumitvpn.sh

        systemctl daemon-reload
        systemctl enable lumitvpn
        systemctl restart lumitvpn
    else
        echo "bootstrap.sh -> $0 - Error: .vpn.env missing."
    fi
}



System_openconnectVpnSupplicantSetup()
{
    printf "\n* Setting up Systemd service for OpenConnect VPN...\n"

    if [ -f /tmp/.vpn.env ]; then
        mkdir -p /etc/openconnect
        mv /tmp/.vpn.env /etc/openconnect/vpn.conf
        chmod 400 /etc/openconnect/vpn.conf

        cat >/etc/systemd/system/openconnect_vpn.service<<EOF
[Unit]
Description=openconnect_vpn
After=network-online.target
Wants=network-online.target

[Service]
Type=idle
RemainAfterExit=no
ExecStartPre=systemctl stop systemd-timesyncd
ExecStart=/sbin/openconnectvpn.sh start
ExecStop=/sbin/openconnectvpn.sh stop
Restart=always
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

        cat >/sbin/openconnectvpn.sh<<'EOF'
#!/bin/bash

if [ -z "$1" ]; then
    echo "usage: $0 start|stop|status"
    exit 0
fi

trim()
{
    echo -n "$(sed -e 's/[[:space:]]*$//' <<<$1)"
}

case $1 in
    start)
        if [ -r /etc/openconnect/vpn.conf ]; then
            username=$(echo $(trim $(cat /etc/openconnect/vpn.conf | awk -F'=' '/openconnect_vpn_username/ {print $2}')))
            password=$(echo $(trim $(cat /etc/openconnect/vpn.conf | awk -F'=' '/openconnect_vpn_password/ {print $2}')))

            sleep 10

            unset https_proxy
            unset http_proxy
            printf $password | openconnect -u "$username" --passwd-on-stdin vpn.regione.fvg.it
        else
            echo "Cannot find credential file."
            exit 1
        fi
        ;;

    stop)
        pkill openconnect
        ;;

    status)
        if ps axu | grep openconnect | grep -vq grep; then
            echo "openconnect is running"
        else
            echo "openconnect not running"
        fi
        ;;
esac

exit 0
EOF
        chmod +x /sbin/openconnectvpn.sh

        systemctl daemon-reload
        systemctl enable openconnect_vpn
        systemctl restart openconnect_vpn
    else
        echo "bootstrap.sh -> $0 - Error: .vpn.env missing."
    fi
}



System_pipInstallDaemon_api()
{
    printf "\n* Setting up Systemd service for installing pip dependencies from project's requirements file...\n"

    # pip install service.
    cp -f /vagrant/api-cisconx/etc/systemd/system/pip_install_api.service /etc/systemd/system/pip_install_api.service
    chmod 644 /etc/systemd/system/pip_install_api.service

    # Watchdog service: monitor folder for changes.
    cp -f /vagrant/api-cisconx/etc/systemd/system/pip_install_api.path /etc/systemd/system/pip_install_api.path
    chmod 644 /etc/systemd/system/pip_install_api.path

    systemctl daemon-reload
    systemctl enable systemd-networkd.service systemd-networkd-wait-online.service

    systemctl enable pip_install_api.path
    systemctl enable pip_install_api.service
    systemctl restart pip_install_api.path
}



System_redisSetup() {
    if ! grep syslog-enabled /etc/redis/redis.conf | grep -Evq '^\s*#'; then
        sed -i -e '$a syslog-enabled yes' /etc/redis/redis.conf
        systemctl restart redis.service
    fi
}



System_celeryStart()
{
    printf "\n* Setting up Systemd service for starting Celery...\n"

    cp -f /vagrant/api-cisconx/usr/bin/celery.sh /usr/bin/celery.sh
    chmod 755 /usr/bin/celery.sh

    cp -f /vagrant/api-cisconx/etc/systemd/system/celery.service /etc/systemd/system/celery.service
    chmod 644 /etc/systemd/system/celery.service

    systemctl daemon-reload
    systemctl enable celery.service
    systemctl restart celery.service
}

# ##################################################################################################################################################
# Main
# ##################################################################################################################################################

ACTION=""
PROXY=""

# Must be run as root (sudo).
ID=$(id -u)
if [ $ID -ne 0 ]; then
    echo "This script needs super cow powers."
    exit 1
fi

# Parse user input.
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --action)
            ACTION="$2"
            shift
            shift
            ;;

        --proxy)
            PROXY="$2"
            shift
            shift
            ;;

        *)
            shift
            ;;
    esac
done

if [ -z "$ACTION" ]; then
    echo "Missing parameters. Use --action install for installation."
else
    System "system"
    $system_run
fi

exit 0


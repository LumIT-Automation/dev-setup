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
            printf "\n* Installing system...\n"
            echo "This script requires a fresh-installation of Debian Bullseye ..."

            System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
            System_sshConfig
            System_proxySet "$PROXY"
            System_installDependencies
            System_pythonSetup
            System_syslogngInstall
            System_mtaSetup
            #System_mariadbSetup "$DATABASE_USER_PASSWORD"
            System_apacheSetup "$SYSTEM_USERS_PASSWORD" "$DATABASE_USER_PASSWORD"
            System_consulAgentInstall
            System_redisSetup
            System_pipInstallDaemon_ui
        else
            echo "A Debian Bullseye operating system is required for the installation. Aborting."
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
        if ! grep -qi 'bullseye' /etc/os-release; then
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

    apt install -y wget git unzip net-tools dos2unix dnsutils curl screen vim # base.
    apt install -y python3-pip python3-dev # base python + dev.
    apt install -y python3-venv # for making the .deb.    
    #apt install -y mariadb-server libmariadb-dev # mariadb server + dev (for the mysqlclient pip package).
    #apt install -y php7.4-mysql php7.4-mbstring # php and php for mysql.
    apt install -y libapache2-mod-php7.4 libapache2-mod-wsgi-py3 # apache for php and python.
    apt install -y redis-server # redis.
    apt install -y rpm # for building rh packages.

    apt clean
}



function System_pythonSetup()
{
    printf "\n* Installing pip dependencies for Django, plus for tower-cli...\n"

    update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1
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
    pip install -r /var/www/ui-backend/backend/pip.requirements # pip install requirements.
}



function System_mariadbSetup()
{
    printf "\n* Setting up MariaDB: user uib...\n"

    databaseUserPassword=$1

    # Enable general log and log error via syslog.
    cp -f /vagrant/uib/etc/mysql/mariadb.conf.d/51-mariadb.cnf /etc/mysql/mariadb.conf.d
    cp -f /vagrant/uib/etc/mysql/mariadb.conf.d/99-log.cnf /etc/mysql/mariadb.conf.d
    chmod 644 /etc/mysql/mariadb.conf.d/*cnf

    cp /lib/systemd/system/mariadb.service /etc/systemd/system
    # By default /etc/systemd/system/mysql.service and mysqld.service are symlink to /lib/systemd/system/mariadb.service.
    sed -i -r -e '/^\[Service\]$/a StandardOutput=syslog\nStandardError=syslog\nSyslogFacility=daemon\nSyslogLevel=warning\nSyslogIdentifier=mysql' /etc/systemd/system/mariadb.service # this one replaces the symlink with a new file.
    chmod 644 /etc/systemd/system/mariadb.service
    ln -s /etc/systemd/system/mariadb.service /etc/systemd/system/mysql.service
    ln -s /etc/systemd/system/mariadb.service /etc/systemd/system/mysqld.service

    sed -i -e 's/bind-address /# bind-address /' /etc/mysql/mariadb.conf.d/50-server.cnf

    systemctl daemon-reload
    systemctl restart mariadb

    if mysql -e "exit" >/dev/null 2>&1; then
        if [ "$(mysql --vertical -e "SELECT User FROM mysql.user WHERE User = 'uib';" | tail -1 | awk '{print $2}')" == "" ]; then
            # User uib not present: create.
            mysql -e "CREATE USER 'uib'@'localhost' IDENTIFIED BY '$databaseUserPassword';"
        else
            # Update user's password.
            mysql -e "SET PASSWORD FOR 'uib'@'localhost' = PASSWORD('$databaseUserPassword');"
        fi
    else
        echo "MariaDB error: shell access disabled."
        exit 1
    fi
}



function System_apacheSetup()
{
    printf "\n* Setting up Apache...\n"

    #cd /tmp

    # /var/www/ui-backend is mounted by Vagrant (share), here lays the Django stub project.
    #if [ ! -d /var/www/ui-backend ]; then
    #    echo "/var/www/ui-backend does not exist, check your Vagrant setup."
    #    exit 1
    #fi

    # Copy phpMyAdmin files.
    #if [ ! -f phpMyAdmin-5.1.3-all-languages.zip ]; then
    #    wget https://files.phpmyadmin.net/phpMyAdmin/5.1.3/phpMyAdmin-5.1.3-all-languages.zip
    #fi

    #unzip phpMyAdmin-5.1.3-all-languages.zip >/dev/null

    #if [ -d /var/www/myadmin ]; then
    #    if [ -d /tmp/myadmin ]; then
    #        rm -Rf /tmp/myadmin
    #    fi
    #    mv /var/www/myadmin /tmp/myadmin
    #
    #    echo "I've found a /var/www/myadmin folder, which I moved to /tmp/."
    # fi
    # mv phpMyAdmin-5.1.3-all-languages /var/www/myadmin
    # chown -R www-data:www-data /var/www/myadmin    

    # Configure phpMyAdmin for direct login.
    # sed -i "s/\$cfg\['Servers'\]\[\$i\]\['auth_type'\].*/\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'config';/g" /var/www/myadmin/libraries/config.default.php
    # sed -i "s/\$cfg\['Servers'\]\[\$i\]\['user'\].*/\$cfg\['Servers'\]\[\$i\]\['user'\] = 'uib';/g" /var/www/myadmin/libraries/config.default.php
    # sed -i "s/\$cfg\['Servers'\]\[\$i\]\['password'\].*/\$cfg\['Servers'\]\[\$i\]\['password'\] = '$2';/g" /var/www/myadmin/libraries/config.default.php

    # Setup the Django project virtual host.
    cp -f /vagrant/uib/etc/apache2/sites-available/001-django.conf /etc/apache2/sites-available/001-django.conf
    chmod 644 /etc/apache2/sites-available/001-django.conf

    # Setup the phpMyAdmin virtual host on port 8300.
    # cp -f /vagrant/uib/etc/apache2/sites-available/001-mysql.conf /etc/apache2/sites-available/001-mysql.conf
    # chmod 644 /etc/apache2/sites-available/001-mysql.conf

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
    
    # if ! grep -q '^Listen 8300$' /etc/apache2/ports.conf; then
        # echo "Listen 8300" >> /etc/apache2/ports.conf
    # fi
      
    # Setup Apache config files for its virtualhosts. 
    a2ensite 001-django
    # a2ensite 001-mysql
    a2query -s 000-default && a2dissite 000-default # disable default site, only if enabled.

    systemctl restart apache2
}



System_consulAgentInstall()
{
    printf "\n* Setting up Consul agent...\n"

    # Install Consul and consul-template.
    apt install -y consul

    # wget https://releases.hashicorp.com/consul-template/0.25.1/consul-template_0.25.1_linux_amd64.tgz
    cp -f /vagrant/uib/usr/bin/consul-template /usr/bin/consul-template
    chmod 755 /usr/bin/consul-template

    # Expose Consul ui-backend service.
    cp -f /vagrant/uib/etc/consul.d/ui-backend.json /etc/consul.d/ui-backend.json
    chmod 644 /etc/consul.d/ui-backend.json

    # Setup a Systemd Consul service unit.
    # Consul will bind to the source IP address which has route to Consul server agent.
    cp -f /vagrant/uib/usr/bin/consul.sh /usr/bin/consul.sh
    chmod 755 /usr/bin/consul.sh

    cp -f /vagrant/uib/etc/systemd/system/consul.service /etc/systemd/system/consul.service
    chmod 644 /etc/systemd/system/consul.service

    # Setup a Systemd Consul template service unit.
    # When a change in the Consul catalog is detected, this service will restart Django/Apache to avoid "caching" of its config file.
    cp -f /vagrant/uib/etc/consul-template-config.hcl /etc/consul-template-config.hcl
    chmod 644 /etc/consul-template-config.hcl

    cp -f /vagrant/uib/etc/consul.d/uib.tmpl /etc/consul.d/uib.tmpl
    chmod 644 /etc/consul.d/uib.tmpl

    cp -f /vagrant/uib/usr/bin/consul-template.sh /usr/bin/consul-template.sh
    chmod 755 /usr/bin/consul-template.sh

    cp -f /vagrant/uib/etc/systemd/system/consul_template.service /etc/systemd/system/consul_template.service
    chmod 644 /etc/systemd/system/consul_template.service

    systemctl daemon-reload

    systemctl enable consul
    systemctl enable consul_template

    systemctl restart consul
    systemctl restart consul_template
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
    echo "$serverAddress    syslog.host" >> /etc/hosts

    # syslog-ng config files.
    cp -f /vagrant/uib/etc/syslog-ng/conf.d/*conf /etc/syslog-ng/conf.d/
    chmod 644 /etc/syslog-ng/conf.d/*conf

    mkdir -p /var/log/automation
    systemctl restart syslog-ng
}



System_mtaSetup()
{
    # Add mta entry in /etc/hosts (mta).
    serverAddress="10.0.111.253"
    sed -r -i '/ mta$/d' /etc/hosts
    echo "$serverAddress    mta" >> /etc/hosts
}



System_redisSetup() {
    if ! grep syslog-enabled /etc/redis/redis.conf| grep -Evq '^\s*#'; then
        sed -i -e '$a syslog-enabled yes' /etc/redis/redis.conf
        systemctl restart redis.service
    fi
}



System_pipInstallDaemon_ui()
{
    printf "\n* Setting up Systemd service for installing pip dependencies from project's requirements file...\n"

    # pip install service.
    cp -f /vagrant/uib/etc/systemd/system/pip_install_ui.service /etc/systemd/system/pip_install_ui.service
    chmod 644 /etc/systemd/system/pip_install_ui.service

    # Watchdog service: monitor folder for changes.
    cp -f /vagrant/uib/etc/systemd/system/pip_install_ui.path /etc/systemd/system/pip_install_ui.path
    chmod 644 /etc/systemd/system/pip_install_ui.path

    systemctl daemon-reload
    systemctl enable systemd-networkd.service systemd-networkd-wait-online.service

    systemctl enable pip_install_ui.service
    systemctl enable pip_install_ui.path
    systemctl restart pip_install_ui.path
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

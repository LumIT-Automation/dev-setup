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

    DATABASE_ROOT_PASSWORD="root"
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
        printf "\n* Installing system...\n"

        System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
        System_sshConfig
        System_proxySet "$PROXY"
        System_installDependencies
        System_syslogngInstall
        System_mtaSetup
        System_consulAgentInstall
        System_dotnetInstall
        System_dotnetStartDaemon
        System_nginxSetup
    else
        exit 1
    fi
}

# ##################################################################################################################################################
# Private static
# ##################################################################################################################################################

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

    apt install -y apt-transport-https ca-certificates wget git unzip net-tools dos2unix dnsutils curl screen gnupg # base.
    apt install -y rpm # for building rh packages.
    apt clean
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
    #cp -f /vagrant/dotnet/etc/syslog-ng/conf.d/*conf /etc/syslog-ng/conf.d/
    #chmod 644 /etc/syslog-ng/conf.d/*conf

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



function System_consulAgentInstall()
{
    printf "\n* Setting up Consul agent...\n"

    apt install -y consul

    # Expose Consul ui service.
    cp -f /vagrant/dotnet/etc/consul.d/dotnet.json /etc/consul.d/dotnet.json
    chmod 644 /etc/consul.d/dotnet.json

    # Setup a Systemd Consul service unit.
    # Consul will bind to the source IP address which has route to Consul server agent.
    cp -f /vagrant/dotnet/usr/bin/consul.sh /usr/bin/consul.sh
    chmod 755 /usr/bin/consul.sh

    cp -f /vagrant/dotnet/etc/systemd/system/consul.service /etc/systemd/system/consul.service
    chmod 644 /etc/systemd/system/consul.service

    systemctl daemon-reload
    systemctl enable consul
    systemctl restart consul
}



System_dotnetInstall()
{
    printf "\n* Install .NET SDK...\n"

    apt-key add /vagrant/dotnet/etc/apt/trusted.gpg.d/microsoft-prod.gpg
    echo "deb [arch=amd64,arm64,armhf] https://packages.microsoft.com/debian/11/prod bullseye main" | tee /etc/apt/sources.list.d/dotnet.list
    apt update
    apt install -y dotnet-sdk-6.0

    apt clean

}



System_dotnetStartDaemon()
{
    printf "\n* Setting up dotnet.run service for starting the development server...\n"

    cp -f /vagrant/dotnet/usr/bin/dotnet.sh /usr/bin/dotnet.sh
    chmod 755 /usr/bin/dotnet.sh

    # Run dotnet.run from systemd.
    cp -f /vagrant/dotnet/etc/systemd/system/dotnet.service /etc/systemd/system/dotnet.service
    chmod 644 /etc/systemd/system/dotnet.service

    systemctl daemon-reload
    systemctl enable systemd-networkd.service systemd-networkd-wait-online.service

    systemctl enable dotnet.service
    systemctl restart dotnet.service
}



function System_nginxSetup()
{
    printf "\n* Installing nginx and setting it up as a reverse proxy...\n"

    apt install -y nginx

    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm -f /etc/nginx/sites-enabled/default
    fi

    # Log via syslog-ng only.
    sed -i '/access_log/d' /etc/nginx/nginx.conf
    sed -i '/error_log/d' /etc/nginx/nginx.conf

    # nginx config.
    cp -f /vagrant/dotnet/etc/nginx/conf.d/* /etc/nginx/conf.d/
    chmod 644 /etc/nginx/conf.d/*

    cp -f /vagrant/dotnet/etc/nginx/sites-enabled/reverse /etc/nginx/sites-enabled/
    chmod 644 /etc/nginx/sites-enabled/*

    # nginx service.
    cp -f /vagrant/dotnet/etc/systemd/system/nginx.service /etc/systemd/system/
    chmod 644 /etc/systemd/system/nginx.service

    cp -f /vagrant/dotnet/usr/bin/nginx.sh /usr/bin/nginx.sh
    chmod 755 /usr/bin/nginx.sh

    systemctl daemon-reload
    systemctl restart nginx
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

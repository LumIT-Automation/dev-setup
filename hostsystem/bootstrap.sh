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
            printf "\n* Installing a syslog-ng log collector...\n"
            echo "This script requires a fresh-installation of Debian Buster..."

            System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
            System_sshConfig
            System_proxySet "$PROXY"
            System_installDependencies
            System_syslogngInstall
            System_postfixConfig
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
        if ! grep -q 'Debian GNU/Linux 11 (bullseye)' /etc/os-release; then
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
        cp -r /tmp/sources.list /etc/apt/sources.list
    else
        sed -i 's/^deb cdrom/#deb cdrom/' /etc/apt/sources.list
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

cat > /tmp/postfix.selections<<EOF
postfix  postfix/compat_conversion_warning: true
postfix  postfix/rfc1035_violation: false
postfix  postfix/lmtp_retired_warning: true
postfix  postfix/mynetworks: 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
postfix  postfix/main_cf_conversion_warning: true
postfix  postfix/main_mailer_type: No configuration
postfix  postfix/newaliases: false
postfix  postfix/chattr: false
postfix  postfix/mailbox_limit: 0
postfix  postfix/mailname: /etc/mailname
EOF

    debconf-set-selections /tmp/postfix.selections
    
    #apt-mark hold grub-pc grub-pc-bin
    #DEBIAN_FRONTEND=noninteractive apt -y upgrade    

    apt install -y wget git unzip net-tools dos2unix vim mc tree # base.
    apt install -y syslog-ng
    DEBIAN_FRONTEND=noninteractive apt install -y postfix mutt s-nail bsd-mailx bc
    apt install -y rpm # for building rh packages.
    apt clean
}


System_syslogngInstall()
{
    mkdir -p /var/log/automation/uif
    mkdir -p /var/log/automation/uib
    mkdir -p /var/log/automation/revp

    # Link config files in log repo.
    cd /var/syslog-ng/etc/syslog-ng/conf.d
    for F in `ls *conf`; do 
        ln -s ${PWD}/${F} /etc/syslog-ng/conf.d
    done

    # Copy apis config files (in production these are in the apis packages) and create relative log folders.
    cd /tmp
    for confDir in `ls -d *_syslog-ng`; do 
        logDir=`echo $confDir | sed 's/_syslog-ng//'`
        mkdir -p /var/log/automation/${logDir}

        cd $confDir && cp * /etc/syslog-ng/conf.d
        cd -
    done

    systemctl restart syslog-ng
}


function System_postfixConfig()
{
    printf "\n* Configuring postfix...\n"

    if [ -r /tmp/smtp-vars.conf ]; then
        . /tmp/smtp-vars.conf
        cp -r /var/smtp/etc/postfix/templates /etc/postfix
        bash /var/smtp/usr/bin/postfix-setup.sh -f $From -a $To -t authsmtp -r $relayHost -n 10.0.111.0/24 -u $relayHostUser:$relayHostPwd
    fi
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

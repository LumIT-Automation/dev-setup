#!/bin/bash

set -vx

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

    hostIp=10.0.111.32
    conjurAdminPwd='CyberArk@123!'
}

# ##################################################################################################################################################
# Public
# ##################################################################################################################################################

#
# Void System_run().
#
function System_run()
{
    if [ "$ACTION" == "run" ]; then
        if System_checkEnvironment; then
            printf "\n* Installing system...\n"
            echo "This script requires a fresh-installation of Debian Bookworm..."

            System_proxySet "$PROXY"
            if System_installConjur; then
              System_setupConjur
              System_syslogngConjurConf
            fi
        else
            echo "A Debian Bookworm operating system is required for the installation. Aborting."
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
        if ! grep -qi 'Debian GNU/Linux 12 (bookworm)' /etc/os-release; then
            return 1
        fi
    else
        return 1
    fi

    return 0
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



function System_installConjur()
{
    printf "\n* Installing conjur...\n"

    mkdir -p /opt/cyberark/conjur/{security,config,backups,seeds,logs}
    touch /opt/cyberark/conjur/config/conjur.yml
    chmod 755 /opt/cyberark/conjur/config
    chmod 644 /opt/cyberark/conjur/config/conjur.yml

    if [ -r /vagrant/api-secops/conjur-container/conjur-appliance-Rls-v13.5.0.tar.gz ] && [ -r /vagrant/api-secops/conjur-container/conjur-cli-go_8.0.18_amd64.deb ]; then
        podman image load -i /vagrant/api-secops/conjur-container/conjur-appliance-Rls-v13.5.0.tar.gz
        apt install /vagrant/api-secops/conjur-container/conjur-cli-go_8.0.18_amd64.deb -y
        return 0
    else
        printf "\n##################################################################################################################################################"
        printf "\n* Conjur installation files not found, skipping"
        printf "\n##################################################################################################################################################"
        return 1
    fi
}



function System_setupConjur()
{
    # Create the seccomp.json conjur config file.
    podman run --rm --entrypoint "/bin/cat" registry.tld/conjur-appliance:13.5.0 /usr/share/doc/conjur/examples/seccomp.json > /opt/cyberark/conjur/security/seccomp.json
    # Create the conjur container.
    podman run --add-host=conjur-1-podman:${hostIp} --name conjur --detach --restart=unless-stopped --cap-add AUDIT_WRITE --publish "443:443" --publish "444:444" --publish "5432:5432" --publish "1999:1999" --log-driver journald --security-opt seccomp=/opt/cyberark/conjur/security/seccomp.json --volume /opt/cyberark/conjur/security:/opt/cyberark/conjur/security:Z --volume /opt/cyberark/conjur/backups:/opt/conjur/backup:Z --volume /opt/cyberark/conjur/seeds:/opt/cyberark/conjur/seeds:Z --volume /opt/cyberark/conjur/logs:/var/log/:Z --volume /opt/cyberark/conjur/config:/etc/conjur/config/:Z conjur-appliance:13.5.0
    # Initialize the conjur services.
    podman exec conjur evoke configure leader --accept-eula --hostname `hostname -f` --leader-altnames conjur-1-podman --admin-password "${conjurAdminPwd}" dgs-lab

    # Login
    # conjur init -u https://apisecops -a dgs-lab --self-signed
    # conjur login -i admin -pCyberArk@123! 
}



System_syslogngConjurConf()
{
    # Fix the syslog-ng main file. Needed to avoid logging also in /var/log/syslog.
    # Move the inclusion of the conf.d files before the log path entries if needed.
    cd /etc/syslog-ng/

    # Add podman interface entry in /etc/hosts (get logs from conjur container).
    echo "10.88.0.1 podmanGw" >> /etc/hosts

    # syslog-ng config files.
    cp -f /vagrant/api-secops/etc/syslog-ng/conjur-conf/*conf /etc/syslog-ng/conf.d/
    chmod 644 /etc/syslog-ng/conf.d/*conf

    systemctl restart syslog-ng

    # Adjust syslog-ng in the conjur container.
    podman cp /vagrant/api-secops/conjur-container/net-dst.conf conjur:/etc/syslog-ng/conf.d/
    podman cp /vagrant/api-secops/conjur-container/syslog-log.conf conjur:/etc/syslog-ng/conf.d/

    podman restart conjur
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


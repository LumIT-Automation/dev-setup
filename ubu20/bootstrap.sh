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
    
    SYSTEM_USERS_PASSWORD="a"
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
            echo "This script requires a fresh-installation of Ubuntu 20.04 ..."

            System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
            System_sshConfig
            System_proxySet "$PROXY"
            System_installDependencies
            System_installPodman
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
        if true; then
        #if ! grep -q 'Debian GNU/Linux 11 (bullseye)' /etc/os-release; then
            return 0
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

    sed -i 's/^deb cdrom/#deb cdrom/' /etc/apt/sources.list
    apt update

    apt install -y wget git unzip dnsutils net-tools dos2unix # base.
    apt clean
}



function System_installPodman()
{
    printf "\n* Installing Podman from saved packages...\n"

    apt install -y vim mc # podman buildah
    apt clean
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

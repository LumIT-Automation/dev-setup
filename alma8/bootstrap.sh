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
            echo "This script requires a fresh-installation of Almalinux 8..."

            System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
            System_sshConfig
            System_proxySet "$PROXY"
            System_installDependencies            
        else
            echo "An Almalinux 8 operating system is required for the installation. Aborting."
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
        if ! grep -q 'AlmaLinux-8' /etc/os-release; then
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
    systemctl restart sshd
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
    dnf update -y
    dnf install net-tools podman buildah vim bash-completion nano -y
    dnf install epel-release -y
    dnf clean all
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

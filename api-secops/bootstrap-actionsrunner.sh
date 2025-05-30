#!/bin/bash

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
    miniKubeIp=192.168.49.2
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
            System_installActionsRunner
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



function System_installActionsRunner()
{
    printf "\n* Installing Actions Runner...\n"

    if [ ! -d /usr/lib/actions-runner ]; then
        mkdir /usr/lib/actions-runner
        cd /usr/lib/actions-runner

        curl -o actions-runner-linux-x64-2.324.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.324.0/actions-runner-linux-x64-2.324.0.tar.gz
        tar -xf actions-runner-linux-x64-2.324.0.tar.gz

        chown -R vagrant:vagrant /usr/lib/actions-runner
        chmod 755 run.sh
    fi

    su - vagrant -c "cd /usr/lib/actions-runner && printf '\n\nvagrant\nY\n' | bash config.sh --url https://github.com/DGSSpa/cyberark-automation-lab --token BJOELS7QLGIVSQIOMO4VGGTIHFPFG"

    printf "\n ################################################################################################################################################################\n"
    printf "\n IF THE PREVIOUS STEP HAS FAILED, PLEASE CHANGE THE actionsrunner TOKEN in bootstrap-actionsrunner.sh AND RE-PROVISION THE VM WITH THE actionsrunner PROVISIONER.\n"
    printf "\n ################################################################################################################################################################\n"

    # ActionsRunner Systemd unit.
    cp -f /vagrant/api-secops/usr/bin/actionsrunner.sh /usr/bin/actionsrunner.sh
    chmod 755 /usr/bin/actionsrunner.sh

    cp -f /vagrant/api-secops/etc/systemd/system/actionsrunner.service /etc/systemd/system/actionsrunner.service
    chmod 644 /etc/systemd/system/actionsrunner.service

    systemctl daemon-reload
    systemctl enable actionsrunner
    systemctl restart actionsrunner
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

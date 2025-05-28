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
            System_installMiniKube
            System_installHelm
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



function System_installMiniKube()
{
    printf "\n* Installing Minikube...\n"

    echo "$miniKubeIp minikube" >> /etc/hosts
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
    apt install -y ./minikube_latest_amd64.deb

    # Minikube Systemd unit.
    cp -f /vagrant/api-secops/usr/bin/minikube.sh /usr/bin/minikube.sh
    chmod 755 /usr/bin/minikube.sh
    cp -f /vagrant/api-secops/etc/systemd/system/minikube.service /etc/systemd/system/minikube.service
    chmod 644 /etc/systemd/system/minikube.service

    su - vagrant -c "minikube start --memory=2200mb --static-ip $miniKubeIp"
    su - vagrant -c "minikube kubectl -- get pods -A"

    systemctl daemon-reload
    systemctl enable minikube
}



function System_installHelm()
{
    printf "\n* Installing Helm...\n"

    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    apt install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    apt update
    apt install helm

    su - vagrant -c "helm repo add external-secrets https://charts.external-secrets.io"
    su - vagrant -c "helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --set installCRDs=true"
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

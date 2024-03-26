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
    ELASTIC_ADMIN_PASSWORD="Password01!"
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
            echo "This script requires a fresh-installation of Debian Bookworm..."

            System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
            System_sshConfig
            System_proxySet "$PROXY"
            System_installDependencies
            System_consulAgentInstall
            System_ElasticSearchInstall "$ELASTIC_ADMIN_PASSWORD"
            System_KibanaInstall "$ELASTIC_ADMIN_PASSWORD"
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

    apt install -y wget git unzip net-tools dnsutils dos2unix curl gpg vim apt-transport-https # base.

    apt clean
}



System_ElasticSearchInstall()
{
    superadminPassword="$1"

    printf "\n* Installing and configuring ElasticSearch...\n"

    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
    apt update
    apt install -y elasticsearch

    # Configure network.
    address=$(ip a | grep 'inet ' | tail -1 | grep -oP '(?<=inet ).*(?=/)')
    sed -i "s/#network.host:.*/network.host: $address/g" /etc/elasticsearch/elasticsearch.yml
    sed -i "s/#http.port.*/http.port: 9200/g" /etc/elasticsearch/elasticsearch.yml

    systemctl daemon-reload
    systemctl enable elasticsearch.service
    systemctl restart elasticsearch.service

    # Setup a superadmin password.
    printf "y\n$superadminPassword\n$superadminPassword\n" | /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -i

    # Testing the installation.
    curl --cacert /etc/elasticsearch/certs/http_ca.crt -u elastic:$superadminPassword https://localhost:9200
}



System_KibanaInstall()
{
    printf "\n* Installing and configuring Kibana...\n"

    apt install -y kibana

    sed -i 's/#server.port:.*/server.port: 8000/g' /etc/kibana/kibana.yml
    sed -i 's/#server.host.*/server.host: 0.0.0.0/g' /etc/kibana/kibana.yml

    systemctl daemon-reload
    systemctl enable kibana.service
    systemctl start kibana.service

    # Couple with ElasticSearch (programmatically).
    /usr/share/kibana/bin/kibana-setup --enrollment-token "$(/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)"
    systemctl restart kibana.service

    echo "Kibana interface is listening on http://10.0.111.200:8000"
    echo "ElasticSearch superadmin user: elastic with password: $1"
}



System_consulAgentInstall()
{
    printf "\n* Setting up the Consul agent...\n"

    # Install Consul.
    wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update
    apt install -y consul

    # Expose Consul elk service.
    cp -f /vagrant/elk/etc/consul.d/elk.json /etc/consul.d/elk.json
    chmod 644 /etc/consul.d/elk.json

    # Setup a Systemd Consul service unit.
    # Consul will bind to the source IP address which has route to Consul server agent.
    cp -f /vagrant/elk/usr/bin/consul.sh /usr/bin/consul.sh
    chmod 755 /usr/bin/consul.sh

    cp -f /vagrant/elk/etc/systemd/system/consul.service /etc/systemd/system/consul.service
    chmod 644 /etc/systemd/system/consul.service

    systemctl daemon-reload
    systemctl enable consul
    systemctl restart consul
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


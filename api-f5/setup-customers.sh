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
    if [ "$ACTION" == "run" ]; then
        if System_checkEnvironment; then
            printf "\n* Configuring system...\n"

            System_useCasesSymlinks
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



System_useCasesSymlinks() {
    if ! df | grep -q customer-usecases; then
        echo "usecases share not found, do not setup usecases."
        return
    fi

    api=api-f5
    tech=f5
    TECH=F5
    customers=$(
        for c in `find /var/www/usecases -maxdepth 1 -mindepth 1 -type d`; do 
            basename $c | sed "s/-${api}//"
        done
    )

    mkdir -p /var/www/customer-usecases

    for customer in $customers; do
        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/controllers/${TECH} && cd ${customer}-${api}/${api}/${tech}/controllers/${TECH} && ln -sf ../../../../../../usecases/${customer}-${api}/${api}/${tech}/controllers/${TECH}/Usecases .
        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/serializers/${TECH} && cd ${customer}-${api}/${api}/${tech}/serializers/${TECH} && ln -sf ../../../../../../usecases/${customer}-${api}/${api}/${tech}/serializers/${TECH}/Usecases .
        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/models/${TECH} && cd ${customer}-${api}/${api}/${tech}/models/${TECH} && ln -sf ../../../../../../usecases/${customer}-${api}/${api}/${tech}/models/${TECH}/Usecases .

        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/controllers/Asset && cd ${customer}-${api}/${api}/${tech}/controllers/Asset && ln -sf ../../../../../../usecases/${customer}-${api}/${api}/${tech}/controllers/Asset/Usecases .
        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/serializers/Asset && cd ${customer}-${api}/${api}/${tech}/serializers/Asset && ln -sf ../../../../../../usecases/${customer}-${api}/${api}/${tech}/serializers/Asset/Usecases .
        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/models/Asset && cd ${customer}-${api}/${api}/${tech}/models/Asset && ln -sf ../../../../../../usecases/${customer}-${api}/${api}/${tech}/models/Asset/Usecases .

        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/helpers/decorators && cd ${customer}-${api}/${api}/${tech}/helpers/decorators && ln -sf ../../../../../../usecases/crif-api-f5/api-f5/f5/helpers/decorators/Usecases .

        cd /var/www/customer-usecases
        cd ${customer}-${api}/${api}/${tech} && ln -sf ../../../../usecases/${customer}-${api}/${api}/${tech}/urlsUsecases .
        
        cd /var/www/customer-usecases
        mkdir -p ${customer}-${api}/${api}/${tech}/sql && cd ${customer}-${api}/${api}/${tech}/sql && ln -sf ../../../../../usecases/${customer}-${api}/${api}/${tech}/sql/Usecases .
    done

    mkdir -p /var/www/api/${tech}/controllers/${TECH}/Usecases && cd /var/www/api/${tech}/controllers/${TECH}/Usecases
    for customer in $customers; do
        ln -sf ../../../../../customer-usecases/${customer}-${api}/${api}/${tech}/controllers/${TECH}/Usecases $customer
    done
    mkdir -p /var/www/api/${tech}/models/${TECH}/Usecases && cd /var/www/api/${tech}/models/${TECH}/Usecases
    for customer in $customers; do
        ln -sf ../../../../../customer-usecases/${customer}-${api}/${api}/${tech}/models/${TECH}/Usecases $customer
    done
    mkdir -p /var/www/api/${tech}/serializers/${TECH}/Usecases && cd /var/www/api/${tech}/serializers/${TECH}/Usecases
    for customer in $customers; do
        ln -sf ../../../../../customer-usecases/${customer}-${api}/${api}/${tech}/serializers/${TECH}/Usecases $customer
    done

    mkdir -p /var/www/api/${tech}/controllers/Asset/Usecases && cd /var/www/api/${tech}/controllers/Asset/Usecases
    for customer in $customers; do
        ln -sf ../../../../../customer-usecases/${customer}-${api}/${api}/${tech}/controllers/Asset/Usecases $customer
    done
    mkdir -p /var/www/api/${tech}/serializers/Asset/Usecases && cd /var/www/api/${tech}/serializers/Asset/Usecases
    for customer in $customers; do
        ln -sf ../../../../../customer-usecases/${customer}-${api}/${api}/${tech}/serializers/Asset/Usecases $customer
    done
    mkdir -p /var/www/api/${tech}/models/Asset/Usecases && cd /var/www/api/${tech}/models/Asset/Usecases
    for customer in $customers; do
        ln -sf ../../../../../customer-usecases/${customer}-${api}/${api}/${tech}/models/Asset/Usecases $customer
    done

    mkdir -p /var/www/api/${tech}/helpers/decorators/Usecases && cd /var/www/api/${tech}/helpers/decorators/Usecases
    for customer in $customers; do
        ln -sf ../../../../../customer-usecases/${customer}-${api}/${api}/${tech}/helpers/decorators/Usecases $customer
    done

    mkdir -p /var/www/api/${tech}/urlsUsecases && cd /var/www/api/${tech}/urlsUsecases
    for customer in $customers; do
        ln -sf ../../../customer-usecases/${customer}-${api}/${api}/${tech}/urlsUsecases/${TECH}UsecasesUrls.py ${customer}.py
    done

    mkdir -p /var/www/api/${tech}/sql/Usecases && cd /var/www/api/${tech}/sql/Usecases
    for customer in $customers; do
        ln -sf ../../../../customer-usecases/${customer}-${api}/${api}/${tech}/sql/Usecases/${tech}AddUsecases.sql ${customer}.sql
    done
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

        *)
            shift
            ;;
    esac
done

if [ -z "$ACTION" ]; then
    echo "Missing parameters. Use --action run for setup."
else
    System "system"
    $system_run
fi

exit 0


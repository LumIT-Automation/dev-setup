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
            printf "\n* Configuting system...\n"

            System_mariadbRestore
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
        if ! grep -q 'bullseye' /etc/os-release; then
            return 1
        fi
    else
        return 1
    fi

    return 0
}



System_mariadbRestore()
{
    printf "\n* Restoring the database from its SQL dump...\n"

    mysql -e 'DROP DATABASE IF EXISTS `sso`;'
    mysql -e 'CREATE DATABASE `sso` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
    mysql -e "GRANT USAGE ON *.* TO 'sso'@'%' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;"
    mysql -e "GRANT ALL privileges ON *.* TO 'sso'@'%';"

    mysql sso < /var/www/aaa/sso/sql/sso.sql

    # Default admin user.
    cd /var/www/aaa
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin@automation.local', 'admin@automation.local', 'password')" | python manage.py shell
}


# ##################################################################################################################################################
# Main
# ##################################################################################################################################################

ACTION=""

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
    echo "Missing parameters. Use --action run for launch."
else
    System "system"
    $system_run
fi

exit 0


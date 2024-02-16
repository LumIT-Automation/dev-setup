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

    pkgVer=`cat /var/www/ui-backend/CONTAINER-DEBIAN-PKG/DEBIAN-PKG/deb.release`
    commit=`tail -1 /var/www/ui-backend/.git/logs/HEAD | awk '{print $2}'`

    mysql -e 'DROP DATABASE IF EXISTS `uib`;'
    mysql -e 'CREATE DATABASE `uib` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci COMMENT ='"'"'pkgVersion='${pkgVer}' commit='${commit}"'"';'

    mysql -e "GRANT USAGE ON *.* TO 'uib'@'%' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;"
    mysql -e "GRANT ALL privileges ON *.* TO 'uib'@'%';"

    mysql uib < /var/www/ui-backend/ui_backend/sql/uib.schema.sql
    mysql uib < /var/www/ui-backend/ui_backend/sql/uib.data.sql
    if [ -f /var/www/ui-backend/ui_backend/sql/uib.data-development.sql ]; then
        mysql uib < /var/www/ui-backend/ui_backend/sql/uib.data-development.sql
    fi
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


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
            printf "\n* Configuring system...\n"

            System_mariadbRestore
            #System_sqliteDbRestore
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
        if ! grep -qi 'Debian GNU/Linux 11 (bullseye)' /etc/os-release; then
            return 1
        fi
    else
        return 1
    fi

    return 0
}



System_mariadbRestore()
{
    printf "\n* Restoring the MySQL database from its SQL dump...\n"

    mysql -e 'DROP DATABASE IF EXISTS `api`;'
    mysql -e 'CREATE DATABASE `api` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
    mysql -e "GRANT USAGE ON *.* TO 'api'@'%' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;"
    mysql -e "GRANT ALL privileges ON *.* TO 'api'@'%';"

    mysql api < /var/www/api/f5/sql/f5.schema.sql
    mysql api < /var/www/api/f5/sql/f5.data.sql
    if [ -f /var/www/api/f5/sql/f5.data-development.sql ]; then
        mysql api < /var/www/api/f5/sql/f5.data-development.sql
    fi
}



System_sqliteDbRestore()
{
    printf "\n* Restoring the sqlite database from main SQL dump...\n"

    # Removing sqlite database file, first.
    if [ -f /var/lib/f5.sqlite ]; then
        rm -f /var/lib/f5.sqlite
    fi

    # Importing MysQL dump into sqlite database file.
    bash /var/www/api/mysql2sqlite.sh api | sqlite3 /var/lib/f5.sqlite

    if [ $? -eq 0 ]; then
        chown www-data:www-data /var/lib/f5.sqlite
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

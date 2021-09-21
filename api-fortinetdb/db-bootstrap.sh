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
            echo "A Debian Buster operating system is required for the installation. Aborting."
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
        if ! grep -q 'Debian GNU/Linux 10 (buster)' /etc/os-release; then
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

    mysql -e 'REVOKE ALL PRIVILEGES, GRANT OPTION FROM  `api`@`localhost`;'
    mysql -e 'DROP DATABASE IF EXISTS `api`;'
    mysql -e 'DROP DATABASE IF EXISTS `soc_db_clienti`;'
    mysql -e 'DROP DATABASE IF EXISTS `soc_extra_data`;'

    mysql -e 'CREATE DATABASE `api` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
    mysql -e 'CREATE DATABASE `soc_db_clienti` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
    mysql -e 'CREATE DATABASE `soc_extra_data` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
    mysql -e 'GRANT USAGE ON *.* TO `api`@`localhost` REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;'
    mysql -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, ALTER, CREATE TEMPORARY TABLES, CREATE VIEW, SHOW VIEW, EXECUTE ON `api`.* TO `api`@`localhost`;'
    mysql -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, ALTER, CREATE TEMPORARY TABLES, CREATE VIEW, SHOW VIEW, EXECUTE ON `soc_db_clienti`.* TO `api`@`localhost`;'
    mysql -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, ALTER, CREATE TEMPORARY TABLES, CREATE VIEW, SHOW VIEW, EXECUTE ON `soc_extra_data`.* TO `api`@`localhost`;'

    mysql api < /var/www/api/fortinetdb/sql/fortinetdb.schema.sql
    mysql api < /var/www/api/fortinetdb/sql/fortinetdb.initialData.sql
    mysql soc_db_clienti < /var/www/api/fortinetdb/sql/soc_db_clienti.sql
    mysql soc_extra_data < /var/www/api/fortinetdb/sql/soc_extra_data.schema.sql
    mysql soc_extra_data < /var/www/api/fortinetdb/sql/soc_extra_data.initialData.sql

    # Insert the lista_comuni from ISTAT.
    cd
    /usr/bin/get_list_comuni.sh
    cd -
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


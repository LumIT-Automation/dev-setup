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
    if [ "$ACTION" == "run" ]; then
        if System_checkEnvironment; then
            printf "\n* Configuring system...\n"
            System_elasticSearchConnection "$ELASTIC_ADMIN_PASSWORD"
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



System_elasticSearchConnection()
{
    printf "\n* Creating connection to ElasticSearch...\n"

    apt install -y jq

    # Create an API key.
    password="$1"
    apiKey=$(curl -u elastic:$password --cacert /etc/elasticsearch/certs/http_ca.crt --insecure --location --request POST 'https://10.0.111.200:9200/_security/api_key' --header 'Content-Type: application/json' --data-raw '{
      "name": "concerto",
      "role_descriptors": {
        "apiZscaler": {
          "cluster": ["monitor"],
          "index": [
            {
              "names": ["zia-users"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-user-groups"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-departments"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-locations"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-location-groups"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-cloud-applications"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-devices"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-device-groups"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-rule-labels"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-policies-firewall"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-admin-audit-log"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-web-insights-log"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-url-category"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-url-categories"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-url-filtering-rule"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-url-filtering-rules"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-file-type-rules"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-ssl-inspection-rules"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-audit-ssl-inspection"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-categories-report"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-categories-assessment"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-rule-filtering-rules-assessment"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            },
            {
              "names": ["zia-categories-lookup-urls"],
              "privileges": ["create_index", "write", "read", "manage", "all"]
            }
          ]
        }
      }
    }') || true

    echo "API KEY: $apiKey"
    ID="$(echo $apiKey | jq '.["id"]')"
    KEY="$(echo $apiKey | jq '.["api_key"]')"

    [ -z $ID ] && ID="\"\""
    [ -z $KEY ] && KEY="\"\""

    cat > /var/www/api/api/settings_elasticSearch.py<<EOF
ELASTICSEARCH_URL = "https://10.0.111.200:9200"
ELASTICSEARCH_TLS_VERIFY = False
ELASTICSEARCH_APIKEY = ($ID, $KEY)
EOF
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

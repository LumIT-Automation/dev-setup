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

    # Delete all ZIA indexes.
    curl -u elastic:$password --cacert /etc/elasticsearch/certs/http_ca.crt --insecure --location --request GET 'https://10.0.111.200:9200/_cat/indices' | awk '{print $3}' | grep zia- | xargs -I {} curl -u elastic:$password --cacert /etc/elasticsearch/certs/http_ca.crt --insecure --location --request DELETE "https://10.0.111.200:9200/{}"

    # Create indexes, one for ZIA controller.
    indexes=$(cat /var/www/api/zscaler/ziaUrls.py | grep -oP "(?<=name=\').*(?=\')" | xargs -I {} echo "{\"names\": [\"{}\"],\"privileges\": [\"create_index\", \"write\", \"read\", \"manage\", \"all\"]},")
    indexes=${indexes::-1}

    set -vx
    apiKey=$(curl -u elastic:$password --cacert /etc/elasticsearch/certs/http_ca.crt --insecure --location --request POST 'https://10.0.111.200:9200/_security/api_key' --header 'Content-Type: application/json' --data-raw "{
      \"name\": \"concerto\",
      \"role_descriptors\": {
        \"apiZscaler\": {
          \"cluster\": [\"monitor\"],
          \"index\": [
            $indexes
          ]
        }
      }
    }") || true
    set +vx

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

#!/bin/bash

function configure() {
    # Configure nginx's sites-enabled in order to proxy to the correct dotnet devel httpd port.
    port=$(cat /var/www/dotnet/Properties/launchSettings.json | grep applicationUrl | grep -oP '(?<=https://localhost:).*(?=;)')
    sed -i "s|proxy_pass.*|proxy_pass https://localhost:$port;|g" /etc/nginx/sites-enabled/reverse
}

case $1 in
        configure)
            configure
            ;;

        *)
            echo $"Usage: $0 {configure}"
            exit 1

esac

exit 0

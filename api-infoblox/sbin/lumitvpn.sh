#!/bin/bash

if [ -z "$1" ]; then
    echo "usage: $0 start|stop|status"
    exit 0
fi

case $1 in
    start)
        if [ -r /etc/openfortivpn/config ]; then
            unset https_proxy
            unset http_proxy

            openfortivpn
        else
            echo "Cannot find credential file."
            exit 1
        fi
        ;;

    stop)
        pkill openfortivpn
        ;;

    status)
        if ps axu | grep openfortivpn | grep -vq grep; then
            echo "openfortivpn is running"
        else
            echo "openfortivpn not running"
        fi
        ;;
esac

exit 0

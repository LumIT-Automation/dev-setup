#!/bin/bash

set -e

function start() {
    /usr/bin/consul agent -server -enable-local-script-checks=true -bootstrap-expect=1 -bind=10.0.111.254 -config-dir=/etc/consul.d/ -data-dir=/var/lib/consul/
}

function stop() {
    /usr/bin/consul leave
}

function reload() {
    /usr/bin/consul reload
}

function restart() {
    stop
    sleep 1
    start
}

case $1 in
        start)
            start
            ;;

        stop)
            stop
            ;;

        reload)
            reload
            ;;

        restart)
            restart
            ;;

        *)
            echo $"Usage: $0 {start|stop|reload|restart}"
            exit 1
esac

exit 0

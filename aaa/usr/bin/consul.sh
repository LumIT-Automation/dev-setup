#!/bin/bash

set -e

function start() {
    /usr/bin/consul agent -enable-local-script-checks=true -bind=$(ip route get 10.0.111.254 | grep -oP "(?<=src\ ).*(?=\ uid)") -config-dir=/etc/consul.d/ -data-dir=/var/lib/consul/ -retry-join 10.0.111.254
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

        join)
            join
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
            echo $"Usage: $0 {start|join|stop|reload|restart}"
            exit 1
esac

exit 0

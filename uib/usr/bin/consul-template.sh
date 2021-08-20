#!/bin/bash

set -e

function start() {
    /usr/bin/consul-template -config=/etc/consul-template-config.hcl
}

function stop() {
    ps=$(ps aux | grep consul-template | grep -v grep | awk '{print $2}')
    if [ -n "$ps" ]; then
        kill -9 $ps
    fi
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

        restart)
            stop
            start
            ;;

        *)
            echo $"Usage: $0 {start|stop|restart}"
            exit 1
esac

exit 0
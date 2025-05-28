#!/bin/bash

miniKubeIp=192.168.49.2

function start() {
    if ! whoami | grep -q vagrant; then
        echo "Wrong user"
        exit 1
    fi
    minikube start --memory=2200mb --static-ip $miniKubeIp
}

function stop() {
    if ! whoami | grep -q vagrant; then
        echo "Wrong user"
        exit 1
    fi
    minikube stop
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

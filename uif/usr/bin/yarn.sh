#!/bin/bash

function start() {
    cd /var/www/ui-frontend
    setsid bash -c 'exec su - vagrant -c "cd /var/www/ui-frontend && yarn start | logger -t yarn" <> /dev/tty2 >&0 2>&1' >> /home/vagrant/yarn.log & # attach yarn to tty2; otherwise it is killed by Systemd.
}

function stop() {
    PS=$(ps axu|grep -P 'node|react|yarn' | grep -Pv 'grep|yarn.sh' | awk '{print $2}')
    if [ -n "$PS" ]; then
        kill $PS
    fi
}

function status() {
    PS=$(ps axu|grep 'node' | grep -v grep | awk '{print $2}')
    if [ -n "$PS" ]; then
        echo "Service running"
    else
        echo "Service not running"
    fi
}

function restart() {
    stop
    sleep .5
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

#!/bin/bash

function start() {
    # Run and watch for changes.
    setsid bash -c 'exec su - vagrant -c "cd /var/www/dotnet && DOTNET_USE_POLLING_FILE_WATCHER=1 DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER=1 dotnet watch run | logger -t dotnet" <> /dev/tty2 >&0 2>&1' >> /tmp/dotnet.log & # attach dotnet to tty2; otherwise it is killed by Systemd.

    # tail -f /var/log/syslog | grep 'Hot reload of changes succeeded'
}

function stop() {
    PS=$(ps axu | grep dotnet | grep -v grep | awk '{print $2}')
    if [ -n "$PS" ]; then
        pkill dotnet
    fi
}

function status() {
    PS=$(ps axu | grep dotnet | grep -v grep | awk '{print $2}')
    if [ -n "$PS" ]; then
        echo "Service running"
    else
        echo "Service not running"
    fi
}

function restart() {
    stop
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

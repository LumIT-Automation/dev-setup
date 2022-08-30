#!/bin/bash

function start() {
    # Run and watch for changes (https://docs.microsoft.com/en-us/aspnet/core/tutorials/dotnet-watch?view=aspnetcore-6.0).
    setsid bash -c 'exec su - vagrant -c "cd /var/www/dotnet && DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER=1 dotnet watch run --disable-hot-reload | logger -t dotnet" <> /dev/tty2 >&0 2>&1' >> /tmp/dotnet.log & # attach dotnet to tty2; otherwise it is killed by Systemd.

    # tail -f /var/log/syslog | grep 'Application started'
}

function stop() {
    PS=$(ps axu | grep dotnet | grep -v grep | awk '{print $2}')
    if [ -n "$PS" ]; then
        pkill -9 dotnet
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

#!/bin/bash

function start()
{
    if [ -x /var/lib/api-venv/bin/celery ]; then
        /var/lib/api-venv/bin/celery worker -l info -n api --app api --workdir /var/www/api
    else
        celery worker -l info -n api --app api --workdir /var/www/api
    fi
}

function stop()
{
    PS=$(ps axu|grep -P 'celery' | grep -v 'grep' | awk '{print $2}')
    if [ -n "$PS" ]; then
        kill $PS
    fi
}

function restart()
{
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

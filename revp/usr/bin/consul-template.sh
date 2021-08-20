#!/bin/bash

set -e

configDir="/etc/consul.d/templates/"

function blank() {
    # Grab all consul-template config files.
    cd $configDir
    for conf in `ls *hcl`; do
        src=$(grep source $conf | awk -F'=' '{print $2}' | sed 's/"//g')
        dst=$(grep destination $conf | awk -F'=' '{print $2}' | sed 's/"//g')
   
        # Blank the target config.
	printf "Blank config $dst\n"
        [ -w $dst ] &&  cat $src | sed -e '/{{ range/,/{{ end/d' > $dst || true
    done
}


function start() {
    # When a change in the Consul catalog is detected, consul-template-config.hcl is executed by consul-template.
    /usr/bin/consul-template -config=$configDir
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

        blank)
            blank
            ;;

        restart)
            stop
            start
            ;;

        *)
            echo $"Usage: $0 {start|stop|restart|blank}"
            exit 1
esac

exit 0

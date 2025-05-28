#!/bin/bash

function start() {
    cd /usr/lib/actions-runner
    ./run.sh
}

case $1 in
        start)
            start
            ;;

        *)
            echo $"Usage: $0 {start}"
            exit 1
esac

exit 0

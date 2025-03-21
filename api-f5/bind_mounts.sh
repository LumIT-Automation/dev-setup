#!/bin/bash
set -vx

tech=f5
TECH=F5
customersDir=/var/www/usecases
apiDir=/var/www/api

/usr/bin/systemctl daemon-reload

function setup() {
    cd $customersDir
    for dir in `find . -maxdepth 1 -mindepth 1  -not -path './.*' -type d`; do
        dirName=`basename $dir`
        api=`ls $dirName | head -n1`
        customer=`echo $dirName | sed "s/-${api}//"`
        for component in models controllers serializers; do
            mkdir -p ${apiDir}/${tech}/${component}/${TECH}/Usecases
            mount -m --bind ${customersDir}/${dirName}/${api}/${tech}/${component}/${TECH}/Usecases ${apiDir}/${tech}/${component}/${TECH}/Usecases/${customer}
        done
    done
}


function break() {
    cd $customersDir
    for dir in `find . -maxdepth 1 -mindepth 1  -not -path './.*' -type d`; do
        dirName=`basename $dir`
        api=`ls $dirName | head -n1`
        customer=`echo $dirName | sed "s/-${api}//"`
        for component in models controllers serializers; do
            umount ${apiDir}/${tech}/${component}/${TECH}/Usecases/${customer} && rm -r ${apiDir}/${tech}/${component}/${TECH}/Usecases/${customer}
        done
        for component in models controllers serializers; do
            rm -r ${apiDir}/${tech}/${component}/${TECH}/Usecases
        done
    done
}


case $1 in
    up)
        setup
        exit 0
        ;;
    down)
        break
        exit 0
        ;;
    *)
        echo "Usage: $0 up"
        exit 1
        ;;
esac

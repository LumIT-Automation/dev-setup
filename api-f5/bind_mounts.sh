#!/bin/bash
set -vx

tech=f5
TECH=F5
customersDir=/var/www/usecases
apiDir=/var/www/api

/usr/bin/systemctl daemon-reload

function setup() {
    cd $customersDir
    for dir in `find . -maxdepth 1 -mindepth 1  -not -path './.*' -not -name '*-Usecases' -type d`; do
        dirName=`basename $dir`
        echo "DIR: ############### $dirName"
        api=`ls $dirName | head -n1`
        customer=`echo $dirName | sed "s/-${api}//"`
        for component in models controllers serializers;do
            mount -m --bind ${customersDir}/${dirName}/${api}/${tech}/${component}/${TECH}/Usecases ${apiDir}/${tech}/${component}/${TECH}/Usecases/${customer}
        done

        touch ${apiDir}/${tech}/sql/Usecases/${customer}.sql
        mount --bind ${customersDir}/${dirName}/${api}/${tech}/sql/${tech}AddUsecases.sql ${apiDir}/${tech}/sql/Usecases/${customer}.sql

        touch ${apiDir}/${tech}/urlsUsecases/${customer}.py
        mount --bind ${customersDir}/${dirName}/${api}/${tech}/${TECH}UsecasesUrls.py ${apiDir}/${tech}/urlsUsecases/${customer}.py
    done
}


function break() {
    cd $customersDir
    for dir in `find . -maxdepth 1 -mindepth 1  -not -path './.*' -not -name '*-Usecases' -type d`; do
        dirName=`basename $dir`
        api=`ls $dirName | head -n1`
        customer=`echo $dirName | sed "s/-${api}//"`
        for component in models controllers serializers; do
            umount ${apiDir}/${tech}/${component}/${TECH}/Usecases/${customer} && rm -r ${apiDir}/${tech}/${component}/${TECH}/Usecases/${customer}
        done

        umount ${apiDir}/${tech}/sql/Usecases/${customer}.sql
        rm ${apiDir}/${tech}/sql/Usecases/${customer}.sql

        umount ${apiDir}/${tech}/urlsUsecases/${customer}.py
        rm ${apiDir}/${tech}/urlsUsecases/${customer}.py
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

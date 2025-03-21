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

        touch ${apiDir}/${tech}/sql/${customer}-${tech}AddUsecases.sql
        mount --bind ${customersDir}/${dirName}/${api}/${tech}/sql/${tech}AddUsecases.sql ${apiDir}/${tech}/sql/${customer}-${tech}AddUsecases.sql

        touch ${apiDir}/${tech}/${customer}-${TECH}UsecasesUrls.py
        mount --bind   ${customersDir}/${dirName}/${api}/${tech}/${TECH}UsecasesUrls.py  ${apiDir}/${tech}/${customer}-${TECH}UsecasesUrls.py
    done
}
#touch /var/www/api/f5/sql/crif-5AddUsecases.sql
#mount --bind /var/www/usecases/crif-api-f5/api-f5/f5/sql/f5AddUsecases.sql /var/www/api/f5/sql/crif-5AddUsecases.sql

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

        umount ${apiDir}/${tech}/sql/${customer}-${tech}AddUsecases.sql
        rm ${apiDir}/${tech}/sql/${customer}-${tech}AddUsecases.sql

        umount ${apiDir}/${tech}/${customer}-${TECH}UsecasesUrls.py
        rm ${apiDir}/${tech}/${customer}-${TECH}UsecasesUrls.py
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

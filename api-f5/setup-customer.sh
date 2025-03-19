#!/bin/bash
set -vx
api=api-f5
technology=f5
TECHNOLOGY=F5
gitRepoDir=(cd `pwd`/../../${api} && pwd)
devSetup=(cd `pwd`/.. && pwd)

if [ -z "$1" ]; then
    echo "Usage: $0 <customer>"
    exit 0
fi

if ! [ -d "/var/www/usecases/$1" ]; then
    echo "Customer $1 not found, check the nfs mount points"
    exit 1
fi

customer="$1"

function cleanupVM() {
    cd /var/www/api/${technology}
    rm -f F5UsecasesUrls.py
    find . -type l -name Usecases -exec rm -f {}\;
    cd -
}

function setupVM() {
    oldPwd=`pwd`
    cd /var/www/api/${technology}/controllers/${TECHNOLOGY} || exit -1
    ln -fs ../../../../Usecases/${technology}/controllers-Usecase /Usecases . || exit -2

    cd /var/www/api/${technology}/serializers/${TECHNOLOGY} || exit -1
    ln -fs ../../../../Usecases/${technology}/serializers-Usecase /Usecases . || exit -2

    cd /var/www/api/${technology}/models/${TECHNOLOGY} || exit -1
    ln -fs ../../../../Usecases/${technology}/models-Usecase /Usecases . || exit -2
    cd $oldPwd
}

function setupHost() {
    oldPwd=`pwd`
    cd $gitRepoDir/${technology}
    ln -s ../../Usecases/${technology}/urls-Usecases ${TECHNOLOGY}UsecasesUrls.py
    cd sql
    ln -s ../../../Usecases/${technology}/sqlUseCases ${technology}.useCases.sql
    cd  -
    cd controllers/${TECHNOLOGY}
    ln -s ../../../../Usecases/f5/controllers-Usecases Usecases
    cd -
    cd serializers/${TECHNOLOGY}
    ln -s ../../../../Usecases/f5/serializers-Usecases Usecases
    cd -
    cd models/${TECHNOLOGY}
    ln -s ../../../../Usecases/f5/models-Usecases Usecases
    cd -

    if ! [ -d ../../Usecases/${technology} ]; then
        mkdir -p ../../Usecases/${technology}
    fi

    cd ../../Usecases/${technology} || { echo "cannot find host Usecases dir" && exit -2 };
    ls -sf ../../customer-usecases/${customer}/${api}/${technology}/${TECHNOLOGY}UsecasesUrls.py urls-Usecases
    ls -sf ../../customer-usecases/${customer}/${api}/${technology}/controllers/${TECHNOLOGY}/Usecases controllers-Usecases
    ls -sf ../../customer-usecases/${customer}/${api}/${technology}/serializers/${TECHNOLOGY}/Usecases serializers-Usecases
    ls -sf ../../customer-usecases/${customer}/${api}/${technology}/models/${TECHNOLOGY}/Usecases models-Usecases
    ls -sf ../../customer-usecases/${customer}/${api}/${technology}/sql/${technology}AddUsecases.sql sqlUseCases

    cd $devSetup
    vagrant provision api${technology} --provision-with db

    cd $oldPwd
}


function cleanupHost() {
    cd $gitRepoDir
    find . -type l -name Usecases -exec rm -f {} \;
    find . -type l -name F5UsecasesUrls.py -exec rm -f {} \;
    find . -type l -name f5.useCases.sql -exec rm -f {} \;
    cd -
}

#!/bin/bash
set -vx

api=api-f5
technology=f5
TECHNOLOGY=F5
gitRepoDir=$(cd `pwd`"/../../${api}" && pwd)
devSetup=$(cd `pwd`"/.." && pwd)

help="Usage: $0 <customer> <setup|clean>"

if [ -z "$1" ]; then
    echo $help
    exit 0
fi

if ! [ -d "${devSetup}/../customer-usecases/${1}" ]; then
    echo "Customer $1 not found, check the customer-usecases git repo"
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
    cd ${gitRepoDir}/${technology}
    ln -sf ../../Usecases/${technology}/urls-Usecases ${TECHNOLOGY}UsecasesUrls.py
    cd sql
    ln -sf ../../../Usecases/${technology}/sqlUseCases ${technology}.useCases.sql
    cd  -
    cd controllers/${TECHNOLOGY}
    ln -sf ../../../../Usecases/f5/controllers-Usecases Usecases
    cd -
    cd serializers/${TECHNOLOGY}
    ln -sf ../../../../Usecases/f5/serializers-Usecases Usecases
    cd -
    cd models/${TECHNOLOGY}
    ln -sf ../../../../Usecases/f5/models-Usecases Usecases
    cd -

    if ! [ -d ../../Usecases/${technology} ]; then
        mkdir -p ../../Usecases/${technology}
    fi

    cd ../../Usecases/${technology} || exit -2
    ln -sf ../../customer-usecases/${customer}/${api}/${technology}/${TECHNOLOGY}UsecasesUrls.py urls-Usecases
    ln -sf ../../customer-usecases/${customer}/${api}/${technology}/controllers/${TECHNOLOGY}/Usecases controllers-Usecases
    ln -sf ../../customer-usecases/${customer}/${api}/${technology}/serializers/${TECHNOLOGY}/Usecases serializers-Usecases
    ln -sf ../../customer-usecases/${customer}/${api}/${technology}/models/${TECHNOLOGY}/Usecases models-Usecases
    ln -sf ../../customer-usecases/${customer}/${api}/${technology}/sql/${technology}AddUsecases.sql sqlUseCases

    cd $oldPwd
}

function cleanupHost() {
    cd $gitRepoDir
    find . -type l -name Usecases -exec rm -f {} \;
    find . -type l -name F5UsecasesUrls.py -exec rm -f {} \;
    find . -type l -name f5.useCases.sql -exec rm -f {} \;
    cd -
}

function reloadDb() {
    cd $devSetup
    vagrant provision api${technology} --provision-with db
    cd -
}



case $2 in
    setup)
        setupHost
        reloadDb
        ;;
    clean)
        cleanupHost
        reloadDb
        ;;
    *)
        echo $help
esac


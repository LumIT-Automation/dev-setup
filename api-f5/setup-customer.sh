#!/bin/bash
set -vx

api=api-f5
vmName=`echo $api | tr -d '-'`
technology=f5
TECHNOLOGY=F5
gitRepoDir=$(cd `pwd`"/../../${api}" && pwd)
devSetup=$(cd `pwd`"/.." && pwd)

help="Usage: $0 <customer> <setup|clean>"

if [ -z "$1" ]; then
    echo $help
    exit 0
fi
customer="$1"

if ! [ -d "${devSetup}/../customer-usecases/${customer}-${api}" ]; then
    echo "Customer $1 not found, check the customer-usecases git repo"
    exit 1
fi


function setup() {
    oldPwd=`pwd`
    cd ${gitRepoDir}/${technology}
    ln -sf ../../Usecases/${technology}/urls-Usecases ${TECHNOLOGY}UsecasesUrls.py
    cd sql
    ln -sf ../../../Usecases/${technology}/sqlUseCases ${technology}.useCases.sql
    cd  -
    cd controllers/${TECHNOLOGY}
    ln -sf ../../../../Usecases/${technology}/controllers-Usecases Usecases
    cd -
    cd serializers/${TECHNOLOGY}
    ln -sf ../../../../Usecases/${technology}/serializers-Usecases Usecases
    cd -
    cd models/${TECHNOLOGY}
    ln -sf ../../../../Usecases/${technology}/models-Usecases Usecases
    cd -

    if ! [ -d ../../Usecases/${technology} ]; then
        mkdir -p ../../Usecases/${technology}
    fi

    cd ../../Usecases/${technology} || exit -2
    ln -sf ../../customer-usecases/${customer}-${api}/${api}/${technology}/${TECHNOLOGY}UsecasesUrls.py urls-Usecases
    ln -sf ../../customer-usecases/${customer}-${api}/${api}/${technology}/controllers/${TECHNOLOGY}/Usecases controllers-Usecases
    ln -sf ../../customer-usecases/${customer}-${api}/${api}/${technology}/serializers/${TECHNOLOGY}/Usecases serializers-Usecases
    ln -sf ../../customer-usecases/${customer}-${api}/${api}/${technology}/models/${TECHNOLOGY}/Usecases models-Usecases
    ln -sf ../../customer-usecases/${customer}-${api}/${api}/${technology}/sql/${technology}AddUsecases.sql sqlUseCases

    cd $devSetup
    vagrant ssh $vmName -c "sudo ln -sf ../../usecases/${customer}-${api}/${api}/${technology}/sql/${technology}AddUsecases.sql /var/www/Usecases/${technology}/sqlUseCases"
    vagrant ssh $vmName -c "sudo ln -sf ../../usecases/${customer}-${api}/${api}/${technology}/${TECHNOLOGY}UsecasesUrls.py /var/www/Usecases/${technology}/urls-Usecases"
    vagrant ssh $vmName -c "sudo ln -sf ../../usecases/${customer}-${api}/${api}/${technology}/controllers/${TECHNOLOGY}/Usecases /var/www/Usecases/${technology}/controllers-Usecases"
    vagrant ssh $vmName -c "sudo ln -sf ../../usecases/${customer}-${api}/${api}/${technology}/serializers/${TECHNOLOGY}/Usecases /var/www/Usecases/${technology}/serializers-Usecases"
    vagrant ssh $vmName -c "sudo ln -sf ../../usecases/${customer}-${api}/${api}/${technology}/models/${TECHNOLOGY}/Usecases /var/www/Usecases/${technology}/models-Usecases"

    cd $oldPwd
}

function cleanup() {
    cd $gitRepoDir
    find . -type l -name Usecases -exec rm -f {} \;
    find . -type l -name ${TECHNOLOGY}UsecasesUrls.py -exec rm -f {} \;
    find . -type l -name ${technology}.useCases.sql -exec rm -f {} \;
    cd -
    cd $devSetup
    vagrant ssh $vmName -c "sudo find /var/www/Usecases/${technology} -type l -exec rm -f {} \;"
    cd -
}

function reloadDb() {
    cd $devSetup
    vagrant provision api${technology} --provision-with db
    cd -
}



case $2 in
    setup)
        setup
        reloadDb
        ;;
    clean)
        cleanup
        reloadDb
        ;;
    *)
        echo $help
esac


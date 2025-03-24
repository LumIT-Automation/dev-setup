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
    ln -sf ../../customer-usecases/controllers-Usecases controllers/${TECHNOLOGY}/Usecases
    ln -sf ../../customer-usecases/serializers-Usecases serializerrs/${TECHNOLOGY}/Usecases
    ln -sf ../../customer-usecases/models-Usecases models/${TECHNOLOGY}/Usecases
    for sqlFile in `ls ../../customer-usecases/sql-Usecases/*sql`; do
        ln -sf ../../customer-usecases/sql-Usecases/${sqlFile} sql/${sqlFie}
    done
    for urlFile in `ls ../../customer-usecases/urls-Usecases/*py`; do
        ln -sf ../../customer-usecases/urls-Usecases/${urlFile} $urlFile
    done

    cd $oldPwd
}

function cleanup() {
    cd $gitRepoDir
    find . -type l -name Usecases -exec rm -f {} \;
    #find . -type l -name ${TECHNOLOGY}UsecasesUrls.py -exec rm -f {} \;
    #find . -type l -name ${technology}.useCases.sql -exec rm -f {} \;
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


#!/bin/bash

api=api-f5
technology=f5
TECHNOLOGY=F5

if [ -z "$1" ]; then
    echo "Usage: $0 <customer>"
    exit 0
fi

if ! [ -d "/var/www/usecases/$1" ]; then
    echo "Customer $1 not found, check the nfs mount points"
    exit 1
fi

cd /var/www/api/${technology}/controllers/${TECHNOLOGY} || exit -1
ln -fs ../../../../usecases/${1}/${api}/${technology}/controllers/${TECHNOLOGY}/Usecases . || exit -2

cd /var/www/api/${technology}/models/${TECHNOLOGY} || exit -1
ln -fs ../../../../usecases/${1}/${api}/${technology}/models/${TECHNOLOGY}/Usecases . || exit -2

cd /var/www/api/${technology}/serializers/${TECHNOLOGY} || exit -1
ln -fs ../../../../usecases/${1}/${api}/${technology}/serializers/${TECHNOLOGY}/Usecases . || exit -2

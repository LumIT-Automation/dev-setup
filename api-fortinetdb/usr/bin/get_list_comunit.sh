#!/bin/bash

wget --no-check-certificate https://www.istat.it/storage/codici-unita-amministrative/Elenco-comuni-italiani.csv

todayFile="comuni-`date +%Y%m%d`.csv"

# Go forward is the file exists and is not empty.
if [ -s Elenco-comuni-italiani.csv ]; then
    # Drop the garbage in the first three lines and convert to utf-8
    tail -n +4 Elenco-comuni-italiani.csv | iconv -f ISO885915 -t UTF8 -o $todayFile

    # Proceed only if the file have more than 7000 lines.
    if (( `wc -l $todayFile | cut -d' ' -f1` > 7000 )); then
        mysql -e "truncate table comuni_italiani" soc_extra_data

        loadCommand="load data local infile \"./$todayFile\" into table comuni_italiani FIELDS TERMINATED BY "'";"'" (@skip1,@skip2,@skip3,@skip4,@skip5,@skip6,comune,@skip8,@skip9,@skip10,regione,provincia,@skip13,@skip14,@skip15,@skip16,@skip17,@skip18,@skip19,@skip20,@skip21,@skip22,@skip23,@skip24,@skip25,@skip26);"
	mysql -e "$loadCommand" soc_extra_data
    fi

    xz -f -z $todayFile
fi

rm -f Elenco-comuni-italiani.csv

exit 0


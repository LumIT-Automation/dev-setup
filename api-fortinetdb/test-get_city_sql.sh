#!/bin/bash

echo 'Via Verrazzano, Verona
VIa Vaila, 3, Gussago (BS)
Via Roma Verona
Verona Via Roma
Verona, Via Bassano da Mantova
Via Bassano da Mantova (Milano)
Via Roma da Mantova (Milano)
Piazza Venezia (Roma)
Piazza Venezia, Roma
Roma Piazza Venezia 
Piazza Venezia, Lido di Camaiore (LU)' | while read line; do echo "$line"; mysql soc_extra_data -e "call P_find_city_in_address('$line');" ; echo '###################'; done

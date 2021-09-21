/*
Procedura che trova la citta' nell'indirizzo
*/

delimiter ;
drop procedure if exists P_find_city_in_address;
delimiter //
create procedure P_find_city_in_address(IN address varchar(255))
    BEGIN
        declare done, idc int;
        declare sstr, city, reg varchar(128);
        declare get_cities CURSOR FOR select id, comune from comuni_italiani;
        declare CONTINUE HANDLER FOR NOT FOUND SET done = true;

        drop temporary table if exists tmpResults;
        create temporary table tmpResults(id int, city varchar(128));

        set done = 0;
        OPEN get_cities;
        g_city: LOOP
            IF done THEN LEAVE g_city; END IF;
            FETCH get_cities INTO idc, city;

            SELECT CONCAT('\\b', city, '\\b') into reg;

            select REGEXP_SUBSTR(address, reg) into sstr;
            IF char_length(sstr) > 0
                THEN
                    insert into tmpResults values (idc, city);
            END IF;

        END LOOP;


        /* 
            drop temporary table tmpResults(id int, city varchar(128));
        */
    END
//

delimiter ;


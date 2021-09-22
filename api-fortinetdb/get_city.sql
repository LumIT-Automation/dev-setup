/* Procedura che trova la citta' nella stringa indirizzo */

delimiter ;
drop procedure if exists P_find_city_in_address;
delimiter //
create procedure P_find_city_in_address(IN address varchar(255))
    BEGIN
        declare done, idc, idres, nl, res, len int;
        declare sstr, sstr2, city,  reg varchar(128);
        declare get_cities CURSOR FOR SELECT id, comune FROM comuni_italiani;
        declare get_cities_tmp CURSOR FOR SELECT * FROM tmpMatches;
        declare CONTINUE HANDLER FOR NOT FOUND SET done = true;

        drop temporary table if exists tmpMatches;
        create temporary table tmpMatches(id int, city varchar(128));

        set done = 0;
        OPEN get_cities;
        g_city: LOOP
            FETCH get_cities INTO idc, city;
            IF done THEN LEAVE g_city; END IF;

            /* Find if a word in the string address matche a city in the `comune` column. */
            SELECT CONCAT('\\b', city, '\\b') into reg;
            SELECT REGEXP_SUBSTR(address, reg) into sstr;

            IF char_length(sstr) > 0
                THEN INSERT into tmpMatches values (idc, city);
            END IF;
        END LOOP;
        CLOSE get_cities;

        SELECT count(*) into nl FROM tmpMatches;
        /* The whole `comune` column was checked, if there is one match the job is done. */
        IF nl < 2
            THEN SELECT * FROM tmpMatches;
        ELSE
            /* More than one matches, drop the false positives (streets with a city name. */
            drop temporary table if exists tmpMatches2;
            create temporary table tmpMatches2(id int, city varchar(128));

            set done = 0; set city = '';
            OPEN get_cities_tmp;
            g_city_t: LOOP
                FETCH get_cities_tmp INTO idc, city;
                IF done THEN LEAVE g_city_t; END IF;

                /* Drop a city if is placed after a keyword (Via, Piazza ...) in the address string */
                SELECT CONCAT('Via ', city, '|Piazza ', city, '|Viale ', city, '|Piazzale ', city, '|Bastioni ', city, '|Strada ', city, '|Vicolo ', city) into reg;
                SELECT address REGEXP reg into res;
                /* res = 0 means "this city is not after a keyword, don't drop it."*/
                IF res = 0
                    THEN INSERT into tmpMatches2 values (idc, city);
                END IF;
            END LOOP;
            CLOSE get_cities_tmp;

            SELECT count(*) into nl FROM tmpMatches2;
            /* If there is one match the job is done. */
            IF nl < 2
                THEN SELECT * FROM tmpMatches2;
            ELSE
                /* Otherwise: choose the city using this standard:
                    - Choose the city before a keyword, if there is one.
                    - Otherwise choose the last city in the string.
                */
                TRUNCATE table tmpMatches;
                INSERT into tmpMatches SELECT * FROM  tmpMatches2;
                set done = 0; set len = 0;  set idc = 0;
                set city = ''; set reg = ''; set sstr = '';
                set reg = '(.*)(Via |Piazza |Viale |Piazzale |Bastioni |Strada |Vicolo )(.*)';
                SELECT REGEXP_REPLACE(address, reg, '\\1') into sstr;
                IF char_length(sstr) > 0
                    THEN 
                    select T1.* 
                    FROM tmpMatches T1
                    INNER JOIN tmpMatches T2 ON T1.id = T2.id
                    WHERE INSTR(sstr, T2.city) > 0;

                ELSE
                    SELECT REGEXP_REPLACE(address, reg, '\\3') into sstr;
                    OPEN get_cities_tmp;
                    g_city_t: LOOP
                        FETCH get_cities_tmp INTO idc, city;
                        IF done THEN LEAVE g_city_t; END IF;
                        SELECT CONCAT(city, '.*') into reg;
                        SELECT REGEXP_REPLACE(sstr, reg, '') into sstr2;

                        IF char_length(sstr2) < char_length(sstr)
                            THEN 
                            IF char_length(sstr2) > len
                                THEN 
                                set len = char_length(sstr2);
                                set idres = idc;
                            END IF;
                        END IF;
                    END LOOP;
                    CLOSE get_cities_tmp;
                    SELECT * FROM tmpMatches where id = idres;
                END IF;
            END IF;        
        END IF;

/*        drop temporary table if exists tmpMatches;
        drop temporary table if exists tmpMatches2; */
    END
//

delimiter ;




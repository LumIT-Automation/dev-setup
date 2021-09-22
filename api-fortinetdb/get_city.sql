/* Procedura che trova la citta' nella stringa indirizzo */

DELIMITER ;
DROP PROCEDURE IF EXISTS P_find_city_in_address;
DELIMITER //
CREATE PROCEDURE P_find_city_in_address(IN address varchar(255))
    BEGIN
        declare done, idc,  nl int;
        declare res_str, city, reg varchar(128);
        declare get_cities CURSOR FOR SELECT id, comune FROM comuni_italiani;
        declare CONTINUE HANDLER FOR NOT FOUND SET done = true;

        DROP temporary TABLE IF EXISTS tmpMatches;
        CREATE temporary TABLE tmpMatches(id int, comune varchar(128));

        SET done = 0;
        OPEN get_cities; /* Scan the `comuni_italiani` TABLE. */
        g_city: LOOP
            FETCH get_cities INTO idc, city;
            IF done THEN LEAVE g_city; END IF;

            /* Check IF a word in the string address matches a city in the `comune` column. 
               If so, insert INTO the tmpMatches TABLE. */
            SELECT CONCAT('\\b', city, '\\b') INTO reg;
            SELECT REGEXP_SUBSTR(address, reg) INTO res_str;

            IF char_length(res_str) > 0
                THEN INSERT INTO tmpMatches values (idc, city);
            END IF;
        END LOOP;
        CLOSE get_cities;

        SELECT count(*) INTO nl FROM tmpMatches;
        /* The whole `comune` column wAS checked, IF there is only one match the job is done. */
        IF nl < 2
            THEN SELECT * FROM tmpMatches;
        ELSE
            /* More than one matches: DROP the false positives (addresses with a city name. */
            DROP temporary TABLE IF EXISTS tmpMatches2;
            CREATE temporary TABLE tmpMatches2(id int, comune varchar(128));

            /* Use a self join of the tmpMatches TABLE to insert INTO tmpMatches2 TABLE 
               the filtered matches.
               For each row of tmpMatches: IF the city name is after a keyword (Via, Piazza ...), 
               DROP it (it means is a street with the name of a city: Via Roma, Piazza Venezia ... ) 
            */
            INSERT INTO tmpMatches2
            SELECT T1.* 
            FROM tmpMatches T1
            INNER JOIN tmpMatches T2 ON T1.id = T2.id
            WHERE address REGEXP CONCAT('Via ', T2.comune, '|Piazza ', T2.comune, '|Viale ', T2.comune, '|Piazzale ', T2.comune, '|Bastioni ', T2.comune, '|Strada ', T2.comune, '|Vicolo ', T2.comune) = 0;

            SELECT count(*) INTO nl FROM tmpMatches2;
            IF nl < 2
                /* If there is still only one match in the tmpMatches2 TABLE then the job is done. */
                THEN SELECT * FROM tmpMatches2;
            ELSE
                /* Otherwise: choose the city using these standards:
                    1) Choose the city before a keyword, IF there is one.
                    2) Otherwise choose the last city in the address string.
                */
                SET reg = ''; SET res_str = '';
                /* Try criterion 1) first */
                SET reg = '(.*)(Via |Piazza |Viale |Piazzale |Bastioni |Strada |Vicolo )(.*)';
                SELECT REGEXP_REPLACE(address, reg, '\\1') INTO res_str;
                IF char_length(res_str) > 0
                    THEN
                    /* WHERE INSTR(res_str, T2.comune) expression seems not work in a direct SELECT to the TABLE.
                       Problem solved using a self join. */
                    SELECT T1.* 
                    FROM tmpMatches2 T1
                    INNER JOIN tmpMatches2 T2 ON T1.id = T2.id
                    WHERE INSTR(res_str, T2.comune) > 0;
                ELSE
                    /* If the res_str string is empty, it means that criterion 2) is needed. */
                    SELECT REGEXP_REPLACE(address, reg, '\\3') INTO res_str;

                    /* In the subquery, for each line:
                       - Cut the string res_str: delete chars starting FROM the match of the `city` field in the
                       string to the end.
                       - Get the lenght of the remaining substring.
                       -Get only the row of the tmpMatches2 TABLE that give the longest substring
                         (it means the city is the last match in the res_str string. 
                    */
                    SELECT T.id, T.comune
                    FROM
                    (
                      SELECT T1.*,
                      char_length(REGEXP_REPLACE(res_str, CONCAT(T2.comune, '.*'), '')) AS srt_len
                      FROM tmpMatches2 T1
                      INNER JOIN tmpMatches2 T2 ON T1.id = T2.id
                      HAVING srt_len = MAX(srt_len)
                    ) AS T;

                END IF;
            END IF;        
        END IF;

        DROP temporary TABLE IF EXISTS tmpMatches;
        DROP temporary TABLE IF EXISTS tmpMatches2;
    END
//

DELIMITER ;




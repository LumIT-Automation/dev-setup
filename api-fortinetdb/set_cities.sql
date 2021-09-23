/* This procedure call the proc P_find_city_in_address to obtain the right city for each address, then
    update the db_apparato_extra_data table */

DELIMITER ;
DROP PROCEDURE IF EXISTS P_db_apparato_extra_data_set_location;
DELIMITER //
CREATE PROCEDURE P_db_apparato_extra_data_set_location()
    BEGIN
        declare done, idc INT;
        declare serial, address, comune varchar(128);
        declare get_addresses CURSOR FOR SELECT SERIALE, INDIRIZZO FROM fed_db_apparato;
        declare CONTINUE HANDLER FOR NOT FOUND SET done = true;

        set done = 0;
        OPEN get_addresses; /* Scan the db_apparato table and process each address. */
        g_addr: LOOP
            FETCH get_addresses INTO serial, address;
            IF done THEN LEAVE g_addr; END IF;
            set idc = 0;

            /* Get the right city of the address of the processed row. */
            call P_find_city_in_address(address, idc);

            /* Update the db_apparato_extra_data table. */
            INSERT INTO db_apparato_extra_data
            (seriale, Descrizione, comune, provincia, targa, regione)
            SELECT 
            serial, '',
            ci.comune, ci.provincia, ci.targa, ci.regione
            FROM comuni_italiani ci WHERE id = idc
            ON DUPLICATE KEY UPDATE 
            `comune` = ci.comune, `provincia` = ci.provincia, `targa` = ci.targa, `regione` = ci.regione;
            
        END LOOP g_addr;
        CLOSE get_addresses;

    END
//

DELIMITER ;




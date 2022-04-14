CREATE FUNCTION %SCHEMA%.index_key_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
            boxId char(1);
    BEGIN

            boxId = RIGHT(NEW.entityid::text, 1);

IF (boxId = '0')
   THEN INSERT INTO %SCHEMA%.index_key_0 VALUES (NEW.*);
ELSIF (boxId = '1')
   THEN INSERT INTO %SCHEMA%.index_key_1 VALUES (NEW.*);
ELSIF (boxId = '2')
   THEN INSERT INTO %SCHEMA%.index_key_2 VALUES (NEW.*);
ELSIF (boxId = '3')
   THEN INSERT INTO %SCHEMA%.index_key_3 VALUES (NEW.*);
ELSIF (boxId = '4')
   THEN INSERT INTO %SCHEMA%.index_key_4 VALUES (NEW.*);
ELSIF (boxId = '5')
   THEN INSERT INTO %SCHEMA%.index_key_5 VALUES (NEW.*);
ELSIF (boxId = '6')
   THEN INSERT INTO %SCHEMA%.index_key_6 VALUES (NEW.*);
ELSIF (boxId = '7')
   THEN INSERT INTO %SCHEMA%.index_key_7 VALUES (NEW.*);
ELSIF (boxId = '8')
   THEN INSERT INTO %SCHEMA%.index_key_8 VALUES (NEW.*);
ELSIF (boxId = '9')
   THEN INSERT INTO %SCHEMA%.index_key_9 VALUES (NEW.*);
ELSIF (boxId = 'a')
   THEN INSERT INTO %SCHEMA%.index_key_a VALUES (NEW.*);
ELSIF (boxId = 'b')
   THEN INSERT INTO %SCHEMA%.index_key_b VALUES (NEW.*);
ELSIF (boxId = 'c')
   THEN INSERT INTO %SCHEMA%.index_key_c VALUES (NEW.*);
ELSIF (boxId = 'd')
   THEN INSERT INTO %SCHEMA%.index_key_d VALUES (NEW.*);
ELSIF (boxId = 'e')
   THEN INSERT INTO %SCHEMA%.index_key_e VALUES (NEW.*);
ELSIF (boxId = 'f')
   THEN INSERT INTO %SCHEMA%.index_key_f VALUES (NEW.*);
ELSE
   INSERT INTO %SCHEMA%.index_key_f VALUES (NEW.*);
END IF;

    RETURN null;
    END;
    $$;


ALTER FUNCTION %SCHEMA%.index_key_insert_trigger() OWNER TO mds;

CREATE TRIGGER index_key_trigger BEFORE INSERT ON %SCHEMA%.index_key FOR EACH ROW EXECUTE PROCEDURE %SCHEMA%.index_key_insert_trigger();
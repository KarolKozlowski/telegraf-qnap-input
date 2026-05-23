DO
$$
DECLARE
    r      record;
    hasrow boolean;
    count  int := 0;
BEGIN
    RAISE NOTICE 'Tables with rows from fqdn.example.com:';

    FOR r IN
        SELECT table_schema, table_name
        FROM   information_schema.tables
        WHERE  table_type = 'BASE TABLE'
        AND    table_schema = 'public'
        ORDER  BY table_name
    LOOP
        EXIT WHEN count >= 40;  -- stop before exhausting locks

        BEGIN
            EXECUTE format(
                'SELECT EXISTS (
                     SELECT 1
                     FROM   %I.%I
                     WHERE  host = %L
                     LIMIT  1
                 )',
                r.table_schema, r.table_name,
                'fqdn.example.com'
            )
            INTO hasrow;

            IF hasrow THEN
                RAISE NOTICE '%', r.table_name;
            END IF;
        EXCEPTION
            WHEN undefined_column THEN
                CONTINUE;
        END;

        count := count + 1;
    END LOOP;
END;
$$;
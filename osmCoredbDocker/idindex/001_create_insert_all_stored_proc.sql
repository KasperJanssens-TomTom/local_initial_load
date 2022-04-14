create or replace procedure insert_all_id_index_data(schema_to text, inout did int) as
$$
declare
    not_processed_dataset_id int := 0;
begin
    execute format('select id from %s.insertion_status WHERE status in (''NOT_STARTED'') LIMIT 1 FOR UPDATE SKIP LOCKED', schema_to) into not_processed_dataset_id;
    if not_processed_dataset_id is not null then
        raise notice 'not processed id: %', not_processed_dataset_id;
        EXECUTE format('UPDATE %s.insertion_status SET started_at = clock_timestamp(), status = ''IN_PROGRESS'' where id = %s', schema_to, not_processed_dataset_id);
        commit;
        EXECUTE format('select insert_id_index_data(schema_to_read, table_to_read, datasetname, ''%s'') from %s.insertion_status where id = %s', schema_to, schema_to, not_processed_dataset_id);
        EXECUTE format('UPDATE %s.insertion_status SET finished_at = clock_timestamp(), status = ''FINISHED'' where id = %s', schema_to, not_processed_dataset_id);
        did := not_processed_dataset_id;
    else
        did := 0;
    end if;
end;
$$ LANGUAGE plpgsql;


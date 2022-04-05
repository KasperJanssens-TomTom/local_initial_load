create or replace function insert_id_index_data(schema_from text, table_from text, dataset_name_from text, schema_to text) RETURNS text AS
$$
begin
	    EXECUTE format('INSERT INTO %s.index_key (entityid, datasetname) SELECT id, ''%s'' from %s.%s where ''%s'' <> ''feature'' or ''%s'' <> substring(decode(replace(id::text, ''-'', ''''), ''hex'') from 3 for 3) or (''x'' || substring(id::text from 1 for 1))::bit(1)::int = 1', schema_to, dataset_name_from, schema_from, table_from, table_from, dataset_name_from);
	    return dataset_name_from;
end;
$$ LANGUAGE plpgsql;

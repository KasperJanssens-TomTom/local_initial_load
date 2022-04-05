INSERT INTO id_index_simplified_00000_0.insertion_status (id, schema_to_read, table_to_read, datasetname) SELECT nextval('id_index_simplified_00000_0.insertion_status_seq'), 'mds_schema', 'attributes', 'GLB' on conflict do nothing;
INSERT INTO id_index_simplified_00000_0.insertion_status (id, schema_to_read, table_to_read, datasetname) SELECT nextval('id_index_simplified_00000_0.insertion_status_seq'), 'mds_schema', 'feature', 'GLB' on conflict do nothing;


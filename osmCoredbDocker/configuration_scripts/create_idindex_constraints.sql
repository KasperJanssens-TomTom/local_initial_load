ALTER TABLE :schema.:table ADD CONSTRAINT index_pkey_%PARTITION% PRIMARY KEY(entityid, value_id);
ALTER TABLE :schema.:table ADD CONSTRAINT index_key_%PARTITION%_index_value_fk FOREIGN KEY (value_id) REFERENCES :schema.index_value (value_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION;
ANALYZE :schema.:table;
ALTER TABLE :schema.:table ADD CONSTRAINT index_key_%PARTITION%_entityid_check CHECK ("right"(entityid::text, 1) = '%PARTITION%'::text);
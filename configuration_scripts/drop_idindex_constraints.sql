ALTER TABLE :schema.:table DROP CONSTRAINT IF EXISTS index_pkey_%PARTITION%;
ALTER TABLE :schema.:table DROP CONSTRAINT IF EXISTS index_key_%PARTITION%_index_value_fk;
ANALYZE :schema.:table;
ALTER TABLE :schema.:table DROP CONSTRAINT IF EXISTS index_key_%PARTITION%_entityid_check;
do $$
begin
    CREATE SCHEMA IF NOT EXISTS id_index_simplified_000000_0;
    CREATE TABLE IF NOT EXISTS id_index_simplified_000000_0.index_key(
     entityid uuid NOT NULL,
     datasetname text COLLATE pg_catalog."default" NOT NULL
     )
     WITH (
    	 OIDS = FALSE
    	 )
     TABLESPACE pg_default;
     
    CREATE SEQUENCE IF NOT EXISTS id_index_simplified_000000_0.insertion_status_seq;
     
    CREATE TABLE IF NOT EXISTS id_index_simplified_000000_0.insertion_status(
             id bigint NOT NULL,
             schema_to_read text NOT NULL,
             table_to_read text NOT NULL,
             datasetname text COLLATE pg_catalog."default" NOT NULL,
             status text COLLATE pg_catalog."default" DEFAULT 'NOT_STARTED' NOT NULL,
             started_at timestamp NULL,
             finished_at timestamp NULL
             );
    ALTER TABLE id_index_simplified_000000_0.insertion_status DROP CONSTRAINT IF EXISTS insertion_status_ukey;    
    ALTER TABLE id_index_simplified_000000_0.insertion_status ADD CONSTRAINT insertion_status_ukey UNIQUE (schema_to_read, table_to_read, datasetname);
end; $$


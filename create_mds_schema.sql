SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

BEGIN;
CREATE SCHEMA %SCHEMA%;

SET search_path TO %SCHEMA%,public;

SET default_with_oids = false;

CREATE OR REPLACE PROCEDURE create_partitions(_tbl regclass)
LANGUAGE plpgsql
AS $$
DECLARE part_name varchar(80);
BEGIN
  for suffix in 0..15 loop
    SELECT _tbl || '_p' || lower(to_hex(suffix)) INTO part_name;
	  EXECUTE 'CREATE TABLE ' || part_name || ' PARTITION OF ' || _tbl || ' FOR VALUES IN (''' || lower(to_hex(suffix)) || ''') WITH (autovacuum_enabled=false, parallel_workers=4);';
  end loop;
END;
$$;

CREATE TABLE association (
  id uuid NOT NULL,
  source_feature_id uuid NOT NULL,
  target_feature_id uuid NOT NULL,
  association_type integer NOT NULL,
  sequence integer NOT NULL
) PARTITION BY LIST (right(lower(id::text), 1));
CALL create_partitions('association');

CREATE TABLE association_property_entry (
  association_id uuid NOT NULL,
  attribute_value_id uuid NOT NULL,
  property_type integer NOT NULL,
  sequence integer NOT NULL
)
WITH (autovacuum_enabled='false', parallel_workers=8);

CREATE TABLE attributes (
  id uuid NOT NULL,
  json jsonb,
  attribute_type integer,
  descendants uuid[] NOT NULL,
  prop_types integer[] NOT NULL,
  attr_types integer[] NOT NULL,
  levels integer[] NOT NULL,
  jsons jsonb[] NOT NULL,
  seqs integer[] NOT NULL,
  sto_ids uuid[] NOT NULL
)
WITH (autovacuum_enabled='false', parallel_workers=8);


CREATE TABLE dictionary (
  id integer NOT NULL,
  ddct_type character varying(100) NOT NULL,
model_version_id integer NOT NULL
)
WITH (autovacuum_enabled='false');


CREATE TABLE feature (
  id uuid NOT NULL,
  feature_type integer NOT NULL,
  geometry_full_geom public.geometry,
  geometry_index public.geometry
) PARTITION BY LIST (right(lower(id::text), 1));
CALL create_partitions('feature');

CREATE TABLE feature_property_entry (
  feature_id uuid NOT NULL,
  attribute_value_id uuid NOT NULL,
  property_type integer NOT NULL,
  sequence integer NOT NULL
) PARTITION BY LIST (right(lower(feature_id::text), 1));
CALL create_partitions('feature_property_entry');

CREATE TABLE metadata (
  metadata_objects_id uuid NOT NULL,
  additional_id text,
  metadata_key text NOT NULL,
  metadata_value text
)
WITH (autovacuum_enabled='false');


CREATE TABLE model_versions (
  id integer NOT NULL,
  model_version character varying(30) NOT NULL
)
WITH (autovacuum_enabled='false');

ALTER SCHEMA %SCHEMA% OWNER TO %OWNER%;

ALTER TABLE %SCHEMA%.association OWNER TO %OWNER%;
ALTER TABLE %SCHEMA%.association_property_entry OWNER TO %OWNER%;
ALTER TABLE %SCHEMA%.attributes OWNER TO %OWNER%;
ALTER TABLE %SCHEMA%.dictionary OWNER TO %OWNER%;
ALTER TABLE %SCHEMA%.feature OWNER TO %OWNER%;
ALTER TABLE %SCHEMA%.feature_property_entry OWNER TO %OWNER%;
ALTER TABLE %SCHEMA%.metadata OWNER TO %OWNER%;
ALTER TABLE %SCHEMA%.model_versions OWNER TO %OWNER%;

DROP PROCEDURE create_partitions;

COMMIT;
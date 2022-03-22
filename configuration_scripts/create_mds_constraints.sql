ALTER TABLE :schema.attributes ADD CONSTRAINT attributes_pkey PRIMARY KEY (id);
ALTER TABLE :schema.dictionary ADD CONSTRAINT dictionary_pkey PRIMARY KEY (id);
ALTER TABLE :schema.model_versions ADD CONSTRAINT model_versions_pkey PRIMARY KEY (id);
INSERT INTO localizer.idindex_connection_settings (id, version, connectionstring, dbschema, branch, engine)
                    VALUES (DEFAULT, 0, 'jdbc:postgresql://test-postgres:5432/coredb', 'id_index_simplified_000000_0', '00000000-0000-0000-0000-000000000000', 'POSTGRESQL') ON CONFLICT DO NOTHING

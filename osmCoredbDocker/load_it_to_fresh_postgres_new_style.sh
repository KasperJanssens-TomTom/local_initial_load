#!/bin/bash

./load_into_postgres_new.sh --database='coredb' --mds-schema='mds_schema' --port='5432' --user='postgres' --db_pwd='hasL0' --owner='postgres' --smds-s3-source=s3://cmr-direct-load-dev/pbf_dump/KasperJanssens/csv/output7ad8643c_f46b_425c_9ee5_25fe8458990e/ --load-id='47622c78-7de1-11ec-90d6-0242ac120003'

#!/bin/bash

./load_into_postgres.sh --database='mds_prod' --mds-schema='newyorkcity_26_01_22 ' --user='kasper' --owner='kasper' --smds-s3-source=s3://cmr-direct-load-serone/customers/1c602015-7b1d-4c37-a3ac-5529daf09fc8/load/47622c78-7de1-11ec-90d6-0242ac120003/generated_csv/GLB/ --skip-idindex --load-id='47622c78-7de1-11ec-90d6-0242ac120003'

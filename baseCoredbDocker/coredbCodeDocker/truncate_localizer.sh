#!/bin/bash
PGPASSWORD=hasL0 psql -h test-postgres -d coredb -p 5432 -U postgres -f truncate.sql
PGPASSWORD=hasL0 psql -h test-postgres -d coredb -p 5432 -U postgres -f truncate_index.sql



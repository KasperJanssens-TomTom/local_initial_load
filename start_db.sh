#!/bin/bash
docker run -d -p 5432:5432 --name test-db-smds -e POSTGRES_USER=kasper -e POSTGRES_PASSWORD=mysecretpassword -e POSTGRES_DB=mds_prod postgres


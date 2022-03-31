#!/bin/bash
set -ex

if [[ $# -ne 1 ]]; then
	echo 'Too many/few arguments, expecting one, the user:group to perform a chown' >&2
	exit 1
fi

pushd baseCoredbDocker || exit

pushd coredbCodeDocker || exit

./build.sh

popd || exit

docker-compose up -d

sleep 5s

docker exec -it basecoredbdocker_coredb-source_1  /run_the_liquibase_scripts.sh

docker-compose down

./build-coredb-db-docker.sh $1

popd || exit

docker run -p 5432:5432 --name coredb-to-load -d cppspdocker.azurecr.io/coredb:1 

sleep 5s

./load_it_to_fresh_postgres.sh

docker commit coredb-to-load cppspdocker.azurecr.io/coredb-osm-hkm:1

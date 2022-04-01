#!/bin/bash
set -ex

if [[ $# -ne 1 ]]; then
	echo 'Too many/few arguments, expecting one, the user:group to perform a chown' >&2
	exit 1
fi

./cleanup.sh

pushd baseCoredbDocker || exit

pushd coredbCodeDocker || exit

./build.sh

popd || exit

docker-compose up -d

sleep 5s

docker exec -it basecoredbdocker_coredb-source_1  /run_the_liquibase_scripts.sh

popd || exit

./load_it_to_fresh_postgres.sh

./build_coredb_osm_hkm_docker.sh "$1"

pushd coredbCodeDocker || exit

docker-compose down

popd || exit

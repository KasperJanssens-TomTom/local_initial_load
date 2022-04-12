#!/bin/bash
set -ex

if [[ $# -eq 0 || $# -gt 2 ]]; then
	echo 'Too few arguments, expecting one, the user:group to perform a chown. ALternatively, pass false as a parameter to not use the new style of input load' >&2
	exit 1
fi

./cleanup.sh

./log_on_through_saml.sh

pushd baseCoredbDocker || exit

pushd coredbCodeDocker || exit

./build.sh

popd || exit

docker-compose up -d

sleep 5s

docker exec -it basecoredbdocker_coredb-source_1  /run_the_liquibase_scripts.sh

popd || exit

new_style="${2:-true}"    # Default value is false
if "$new_style"; then
	echo "new style input load"
        ./load_it_to_fresh_postgres_new_style.sh
else
	echo "old style input load"
        ./load_it_to_fresh_postgres.sh
fi


pushd idindex || exit

./load_all_scripts.sh --database=coredb --user=postgres --db_pwd=hasL0 --port=5432

popd || exit

./build_coredb_osm_hkm_docker.sh "$1"

pushd baseCoredbDocker || exit

docker-compose down

popd || exit

#!/bin/bash
set -euxo

function show_usage {
  echo
  echo "Usage: $0 [OPTION]"
  echo "Builds empty coredb layer from empty postgis by applying liquibase scripts on top"
  echo
  echo "  --user/group=NAME [Required] user:group for chowning data folder created by postgisxd"
  echo "  --version=VERSION [Optional] Version of docker to be built"
  echo "  --new-style=NEWSTYLE [Optional] Use the new style of direct load or the old style. True means new style. True is default"
  echo "  --skip-saml=SKIP_SAML [Optional] Skip Saml, when passed the script will assume saml check already done elsewhere"
  echo "  -help, --help              Show this help"
  exit 1
}

if [ $# -eq 0 ]; then
  echo "There are mandatory parameters"
  show_usage
fi

for i in "$@"; do
  case $i in
  --usergroup=*)
    USERGROUP="${i#*=}"
    shift
    ;;
  --version=*)
    VERSION="${i#*=}"
    shift
    ;;
  --new-style=*)
    NEWSTYLE="${i#*=}"
    shift
    ;;
  --skip-saml)
    SKIP_SAML=true
    shift
    ;;
  -help | --help)
    show_usage
    ;;
  *)
    echo "unknown option: ${i#*=}"
    show_usage
    ;;
  esac
done

if [[ -z "$USERGROUP" ]]; then
	echo "USERGROUP is mandatory"
	exit
fi

./configure.sh

./cleanup.sh

if [[! ${SKIP_SAML:-false} ]]
  ./log_on_through_saml.sh
fi

pushd baseCoredbDocker || exit

pushd coredbCodeDocker || exit

./build.sh

popd || exit

docker-compose up -d

sleep 5s

docker exec -it basecoredbdocker_coredb-source_1  /run_the_liquibase_scripts.sh

popd || exit

pushd osmCoredbDocker || exit

new_style="${NEWSTYLE:-true}" 
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

popd || exit

pushd baseCoredbDocker || exit

./build_coredb_osm_hkm_docker.sh "${USERGROUP}" "${VERSION:-2}"

docker-compose down --remove-orphans

popd || exit

#!/bin/bash
set -euxo

function show_usage {
  echo
  echo "Usage: $0 [OPTION]"
  echo "Builds empty coredb layer from empty postgis by applying liquibase scripts on top"
  echo
  echo "  --user/group=NAME [Required] user:group for chowning data folder created by postgisxd"
  echo "  --version=VERSION [Optional] Version of docker to be built"
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

./log_on_through_saml.sh

pushd baseCoredbDocker || exit

pushd coredbCodeDocker || exit

./build.sh

popd || exit

docker-compose up -d

sleep 5s

docker exec -it basecoredbdocker_coredb-source_1  /run_the_liquibase_scripts.sh

./build_coredb_db_docker.sh "${USERGROUP}" "${VERSION:-2}"

docker-compose down --remove-orphans

popd || exit

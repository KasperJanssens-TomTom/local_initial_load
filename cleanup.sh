#!/bin/bash

pushd osmCoredbDocker || exit

rm -rf tmp

popd || exit

pushd baseCoredbDocker || exit

docker-compose down --remove-orphans

sudo rm -rf data

popd || exit

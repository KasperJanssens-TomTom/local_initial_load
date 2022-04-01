#!/bin/bash

rm -rf tmp

pushd baseCoredbDocker || exit

sudo rm -rf data

popd || exit

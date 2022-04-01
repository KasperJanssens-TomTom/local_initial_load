#!/bin/bash

sudo chown -R "$1" baseCoredbDocker/data/

docker build . -t cppspdocker.azurecr.io/coredb-osm-hkm:1

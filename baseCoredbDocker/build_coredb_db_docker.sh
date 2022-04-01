#!/bin/bash

sudo chown -R "$1" data/

docker build . -t cppspdocker.azurecr.io/coredb:1

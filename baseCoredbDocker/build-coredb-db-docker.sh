#!/bin/bash

sudo chown -R "$1" data/

docker build . -t mycoredb-docker-4-real

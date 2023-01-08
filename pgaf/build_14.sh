#!/bin/bash

CUR_PWD=$(pwd)

cd "$CUR_PWD/14"
docker build \
    -t neuroforgede/pgaf-swarm:14 \
    -t neuroforgede/pgaf-swarm:14.6 \
    -f Dockerfile .

docker push neuroforgede/pgaf-swarm:14
docker push neuroforgede/pgaf-swarm:14.6
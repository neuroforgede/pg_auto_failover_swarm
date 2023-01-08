#!/bin/bash

CUR_PWD=$(pwd)

cd "$CUR_PWD/pgaf"
docker build -t neuroforgede/pgaf-swarm:14.6 -f Dockerfile .

docker push neuroforgede/pgaf-swarm:14.6
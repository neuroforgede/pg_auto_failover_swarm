#!/bin/bash

CUR_PWD=$(pwd)

cd "$CUR_PWD/pgaf"
docker build -t none.local/pgaf:latest -f Dockerfile .

cd "$CUR_PWD/haproxy"
docker build -t none.local/haproxy:latest -f Dockerfile .
#!/bin/bash

# base structure of this file is from https://gist.github.com/nicosingh/9583fe487bddf853c38a5b8c9db2cf7a

# initially from from https://github.com/docker-library/postgres/blob/master/15/bullseye/docker-entrypoint.sh
# used to create initial postgres directories and if run as root, ensure ownership to the "postgres" user
docker_create_db_directories() {
  local user
  user="$(id -u)"

  mkdir -p "/var/lib/postgresql/data"
  # ignore failure since there are cases where we can't chmod (and PostgreSQL might fail later anyhow - it's picky about permissions of this directory)
  chmod 700 "/var/lib/postgresql/data" || :

  mkdir -p /var/lib/postgresql/data/cluster
  chown -R postgres:postgres /var/lib/postgresql/data

  # ignore failure since it will be fine when using the image provided directory; see also https://github.com/docker-library/postgres/pull/289
  mkdir -p /var/run/postgresql || :
  chmod 775 /var/run/postgresql || :
}

create_monitor() {
  echo "creating data monitor..."
  # FIXME: check if already initialized
  sudo -u postgres /usr/bin/pg_autoctl create monitor \
    --pgdata /var/lib/postgresql/data/cluster \
    --pgctl /usr/lib/postgresql/14/bin/pg_ctl \
    --skip-pg-hba \
    --no-ssl
  # FIXME: check error codes
}

create_postgres() {
  echo "creating data node..."
  # FIXME: check if already initialized
  sudo -u postgres /usr/bin/pg_autoctl create postgres \
    --pgdata /var/lib/postgresql/data/cluster \
    --monitor postgres://autoctl_node@monitor:5432/pg_auto_failover \
    --hostname $(hostname) \
    --pgctl /usr/lib/postgresql/14/bin/pg_ctl \
    --skip-pg-hba \
    --no-ssl
  # FIXME: check error codes
}

# FIXME: mount pg_hba.conf
#        mount postgresql.conf

setup_hba_monitor() {
  cp /etc/pgaf_swarm/pg_hba_monitor.conf /var/lib/postgresql/data/cluster/pg_hba.conf || exit 1
  chown postgres:postgres /var/lib/postgresql/data/cluster/pg_hba.conf
}

setup_hba_node() {
  cp /etc/pgaf_swarm/pg_hba_node.conf /var/lib/postgresql/data/cluster/pg_hba.conf || exit 1
  chown postgres:postgres /var/lib/postgresql/data/cluster/pg_hba.conf
}

pg_autoctl_run() {
  echo "[entrypoint] starting postgres..."
  exec sudo -u postgres /usr/bin/pg_autoctl run --pgdata /var/lib/postgresql/data/cluster
}

case "${@}" in
monitor)
  docker_create_db_directories
  create_monitor
  setup_hba_monitor
  pg_autoctl_run
  ;;
db-server)
  docker_create_db_directories
  create_postgres
  setup_hba_node
  pg_autoctl_run
  ;;
*)
  echo "command '${@}' not supported"
  exit 1
  ;;
esac

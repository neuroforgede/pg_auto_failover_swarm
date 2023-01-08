#!/bin/bash

log() {
  echo "[pgaf-swarm] $1"
}

error() {
  log "Error: $1"
}

check_result () {
    ___RESULT=$?
    if [ $___RESULT -ne 0 ]; then
        error $1
        exit 1
    fi
}

docker_setup_env() {
	declare -g DATABASE_ALREADY_EXISTS
	if [ -s "/var/lib/postgresql/.config/pg_autoctl/var/lib/postgresql/data/cluster/pg_autoctl.cfg" ]; then
		DATABASE_ALREADY_EXISTS='true'
    log "cluster is already initialized, skipping setup..."
	fi
}

# base structure of this file is from https://gist.github.com/nicosingh/9583fe487bddf853c38a5b8c9db2cf7a

# initially from from https://github.com/docker-library/postgres/blob/master/15/bullseye/docker-entrypoint.sh
# used to create initial postgres directories and if run as root, ensure ownership to the "postgres" user
docker_create_db_directories() {
  if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
    local user
    user="$(id -u)"

    mkdir -p "/var/lib/postgresql/data/cluster"

    mkdir -p /var/lib/postgresql/.postgresql
    ln -s /var/run/secrets/ssl_key /var/lib/postgresql/.postgresql/postgresql.key
    ln -s /var/run/secrets/ssl_cert /var/lib/postgresql/.postgresql/postgresql.crt
    chown -R postgres:postgres /var/lib/postgresql/.postgresql

    mkdir -p /var/lib/postgresql/data/cluster
    chown -R postgres:postgres /var/lib/postgresql/data

    # ignore failure since it will be fine when using the image provided directory; see also https://github.com/docker-library/postgres/pull/289
    mkdir -p /var/run/postgresql || :
    chmod 775 /var/run/postgresql || :
  fi
}

create_monitor() {
  if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
    log "creating data monitor..."
    # FIXME: check if already initialized
    sudo -u postgres /usr/bin/pg_autoctl create monitor \
      --pgdata /var/lib/postgresql/data/cluster \
      --pgctl /usr/lib/postgresql/14/bin/pg_ctl \
      --hostname "${PGAF_HOSTNAME}" \
      --skip-pg-hba \
      --ssl-ca-file "$PGAF_SSL_CA" \
      --server-cert "$PGAF_SSL_CERT" \
      --server-key "$PGAF_SSL_KEY" \
      --ssl-mode "$PGAF_SSL_MODE"
    check_result "failed to create monitor"
    # FIXME: check error codes
  fi
}

create_postgres() {
  if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
    log "creating data node..."
    # FIXME: check if already initialized
    # TODO: make monitor url configurable
    sudo -u postgres /usr/bin/pg_autoctl create postgres \
      --pgdata /var/lib/postgresql/data/cluster \
      --monitor "postgres://autoctl_node@${PGAF_MONITOR_HOSTNAME}:5432/pg_auto_failover" \
      --hostname "${PGAF_HOSTNAME}" \
      --name "${PGAF_NAME}" \
      --pgctl /usr/lib/postgresql/14/bin/pg_ctl \
      --skip-pg-hba \
      --ssl-ca-file "$PGAF_SSL_CA" \
      --server-cert "$PGAF_SSL_CERT" \
      --server-key "$PGAF_SSL_KEY" \
      --ssl-mode "$PGAF_SSL_MODE"
    check_result "failed to create postgres"
    # FIXME: check error codes
  fi
}

setup_pg_ident_conf() {
  cp /etc/pgaf/config/pg_ident.conf /var/lib/postgresql/data/cluster/pg_ident.conf
  check_result "failed to copy /etc/pgaf/config/pg_ident.conf to /var/lib/postgresql/data/cluster/pg_ident.conf"
}

setup_postgresql_conf() {
  cp /etc/pgaf/config/postgresql.custom.conf /var/lib/postgresql/data/cluster/postgresql.custom.conf
  check_result "failed to copy /etc/pgaf/config/postgresql.custom.conf to /var/lib/postgresql/data/cluster/postgresql.custom.conf"
  chown postgres:postgres /var/lib/postgresql/data/cluster/postgresql.custom.conf
  check_result "failed to chown postgres:postgres to /var/lib/postgresql/data/cluster/postgresql.custom.conf"
  LINE="include 'postgresql.custom.conf'"
  FILE="/var/lib/postgresql/data/cluster/postgresql.conf"
  grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
  check_result "failed to append inclusion of custom config file to $FILE"
}

setup_hba_monitor() {
  cp /etc/pgaf/config/pg_hba_monitor.conf /var/lib/postgresql/data/cluster/pg_hba.conf
  check_result "failed to copy /etc/pgaf/config/pg_hba_monitor.conf to /var/lib/postgresql/data/cluster/pg_hba.conf"
  chown postgres:postgres /var/lib/postgresql/data/cluster/pg_hba.conf
  check_result "failed to chown postgres:postgres to /var/lib/postgresql/data/cluster/pg_hba.conf"
}

setup_hba_node() {
  cp /etc/pgaf/config/pg_hba_node.conf /var/lib/postgresql/data/cluster/pg_hba.conf
  check_result "failed to copy /etc/pgaf/config/pg_hba_node.conf to /var/lib/postgresql/data/cluster/pg_hba.conf"
  chown postgres:postgres /var/lib/postgresql/data/cluster/pg_hba.conf
  check_result "failed to chown postgres:postgres to /var/lib/postgresql/data/cluster/pg_hba.conf"
}

pg_autoctl_run() {
  log "starting pg_autoctl..."
  exec sudo -u postgres /usr/bin/pg_autoctl run --pgdata /var/lib/postgresql/data/cluster
}

run_sql() {
  exec sudo -u postgres psql \
    "host=node1.local,node2.local \
    user=postgres \
    sslkey=$PGAF_SSL_KEY \
    sslcert=$PGAF_SSL_CERT \
    sslmode=verify-ca \
    sslrootcert=$PGAF_SSL_CA \
    target_session_attrs=read-write" \
    "$@"
}

case "$1" in
monitor)
  docker_setup_env
  docker_create_db_directories
  create_monitor
  setup_pg_ident_conf
  setup_postgresql_conf
  setup_hba_monitor
  pg_autoctl_run
  ;;
db-server)
  docker_setup_env
  docker_create_db_directories
  create_postgres
  setup_pg_ident_conf
  setup_postgresql_conf
  setup_hba_node
  pg_autoctl_run
  ;;
psql)
  shift
  run_sql "$@"
  ;;
*)
  error "command '${@}' not supported"
  exit 1
  ;;
esac

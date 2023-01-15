# How to migrate from a single docker container

Operating pg_auto_failover_swarm (pgaf-swarm for short) is intended to be as simple as possible.
This includes migrating from a PoC deployment of a Postgres container in Docker Swarm to a fully HA capable
deployment. Following will be a step-by-step guide on how to achieve this.

## Setup some variables to make the commands easier

```bash
export REPO_DIR="<path to the base of the pg_auto_failover_swarm repo>"
```

## Setting up the lab - the single postgres container

First, switch into the resource directory

```bash
export DOCS_BASE_DIR="$REPO_DIR/docs/migrate-from-single-container/resources"
cd "$DOCS_BASE_DIR/original_stack/"
```

If you haven't already, set up a single node swarm:

```bash
docker swarm init
```

Next, setup the single-postgres stack:

```bash
docker stack deploy -c single-postgres.yml single_postgres
```

Verify that the postgres service is running fine:

```bash
docker service ps single_postgres_postgres
```

We can now open a shell in the postgres container:

```bash
docker exec -u 999 -it $(docker ps -q --filter name=single_postgres_postgres) bash
```

Here we can create some tables and insert some test data:

```bash
psql -U mypguser -c 'CREATE TABLE MyTestTable(testcol integer);'
psql -U mypguser -c 'INSERT INTO MyTestTable(testcol) SELECT * FROM generate_series(1::integer, 100::integer)';
psql -U mypguser -c 'SELECT count(*) FROM MyTestTable';
exit
```

## Shut down the old stack and prepare the new data volume

Next, to prepare the migration, we will shut down the single postgres stack but leave the volume in place:

```bash
docker stack rm single_postgres
```

Next, we will prepare a new data volume for our HA stack to seed from. For this, we first create a new volume
that will hold the data for our initial data node. For this we will use another stack that will
do all the logic for us:

```bash
cd "$DOCS_BASE_DIR/create_new_volume/"
docker stack deploy -c create-new-volume.yml create_new_volume
```

We can check out the logs of this process:

```bash
docker service logs create_new_volume_initialize
```

Once finished, we can remove the stack, we don't need it anymore.

```bash
docker stack rm create_new_volume
```

After this process we should now have two volumes, so

```bash
docker volume ls
```

should print something like this:

```
local     my_postgres_data
local     pgaf_test_vol_node_1
```
## Spin up the HA cluster with one data node

Next, we spin up the new HA cluster with a single data node. We do this
so that the cluster gets initialized with the original data from the single node.
We will spin up more data nodes in a later step.

To start, we will generate a new pgaf cluster configuration:

```bash
export BASE_DIR="$REPO_DIR"
export WORKDIR="$(pwd)/test"
export CHART_DIR="../chart"
export START_PWD=$(pwd)

mkdir -p $WORKDIR/overrides/templates

echo "nothelm run deploy --project-dir $CHART_DIR --project-dir overrides -f values.yaml" > $WORKDIR/setup.sh

cat > $WORKDIR/values.yaml << EOF
stack_name: "pgaf_test"

pgaf_swarm_version: "0.1.7-15"

postgres_nodes:
  - name: "node_1"
    hostname: "node1.local"
    # this is the default, but can be overridden
    pgdata: "/var/lib/postgresql/data"
    placement: {}
    # this is the default, but can be overridden
    volume_mount: "/var/lib/postgresql"
    volume_config:
      name: "pgaf_test_vol_node_1"

# commented out, we will need it later
#   - name: "node_2"
#     hostname: "node2.local"
#     # this is the default, but can be overridden
#     pgdata: "/var/lib/postgresql/data"
#     placement: {}
#     # this is the default, but can be overridden
#     volume_mount: "/var/lib/postgresql"
#     volume_config:
#       name: "pgaf_test_vol_node_2"

# this is the default, but can be overridden
monitor_node_hostname: "monitor.local"

monitor_node_volume_config: {}
  # driver: hetzner-volume
  # driver_opts:
  #   name: "monitor"
  #   size: '10'
  #   fstype: ext4
  #   uid: "999"
  #   gid: "999"

# this is the default, but can be overridden
monitor_node_pgdata: "/var/lib/postgresql/data"
monitor_node_volume_mount: /var/lib/postgresql

EOF

cp -r "$BASE_DIR/certificates" "$WORKDIR/overrides/templates/certs"
cd "$WORKDIR/overrides/templates/certs"
bash recreate_root_cert.sh
bash recreate_server_certs.sh
```

Next, we can run the setup for pgaf:

```bash
cd $WORKDIR
bash setup.sh
```

We can watch the logs for node_1 initialize (Ctrl-C to exit):

```bash
docker service logs -f pgaf_test_node_1
```

## Scale up the HA cluster with a second node

Earlier, we generated a values.yaml file that contained a commented out second node, we can uncomment the following section:

```bash
  - name: "node_2"
    hostname: "node2.local"
    # this is the default, but can be overridden
    pgdata: "/var/lib/postgresql/data"
    placement: {}
    # this is the default, but can be overridden
    volume_mount: "/var/lib/postgresql"
    volume_config:
      name: "pgaf_test_vol_node_2"
```

And we can run the setup again:

```bash
cd $WORKDIR
bash setup.sh
```

We should now see the second node joining the cluster:

```bash
docker service logs -f pgaf_test_node_2
```

To verify that everything has worked, we can now open a bash in the pgaf admin container:

```bash
docker exec -it $(docker ps -q --filter name=pgaf_test_admin) bash
pgaf psql 
\c mypguser
SELECT count(*) FROM MyTestTable;
```

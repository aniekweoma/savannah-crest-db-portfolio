#!/usr/bin/env bash
# Savannah Crest Hotels: PostgreSQL primary + streaming standby in Docker
NET=savannah-net
P() { sudo docker exec -i savannah-pg-primary psql -U postgres "$@"; }
S() { sudo docker exec -i savannah-pg-standby psql -U postgres "$@"; }
wait_for() {   # wait_for <container> <log text> <times>
  for i in $(seq 180); do
    [ "$(sudo docker logs "$1" 2>&1 | grep -c "$2")" -ge "$3" ] && return 0; sleep 1
  done; echo "Timed out waiting for $1"; exit 1
}

sudo docker network create $NET 2>/dev/null
sudo docker rm -f savannah-pg-primary savannah-pg-standby 2>/dev/null

echo "== 1. Start the primary =="
sudo docker run -d --name savannah-pg-primary --network $NET -e POSTGRES_PASSWORD=primarypass postgres:17
wait_for savannah-pg-primary "ready to accept connections" 2

echo "== 2. Allow a replication user =="
P -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replpass';"
sudo docker exec savannah-pg-primary bash -c "echo 'host replication replicator all scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"
P -c "SELECT pg_reload_conf();"

echo "== 3. Copy the savannah_crest database into the primary =="
P -c "CREATE DATABASE savannah_crest;"
pg_dump -U postgres -h localhost savannah_crest | P -q -d savannah_crest > /dev/null
P -d savannah_crest -c "SELECT count(*) AS reservations_on_primary FROM reservations;"

echo "== 4. Start the standby (clone the primary, then keep following it) =="
sudo docker run -d --name savannah-pg-standby --network $NET --user postgres -e PGPASSWORD=replpass postgres:17 \
  bash -c "pg_basebackup -h savannah-pg-primary -U replicator -D /var/lib/postgresql/data -R -X stream \
           && chmod 0700 /var/lib/postgresql/data && exec postgres -D /var/lib/postgresql/data"
wait_for savannah-pg-standby "ready to accept read-only connections" 1

echo "== 5. Check =="
P -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
S -c "SELECT pg_is_in_recovery() AS is_standby;"
S -d savannah_crest -c "SELECT count(*) AS reservations_on_standby FROM reservations;"

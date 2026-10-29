#!/usr/bin/env bash
# Savannah Crest Hotels: replication demos (Portfolio 5)
P() { sudo docker exec -i savannah-pg-primary psql -U postgres -d savannah_crest "$@"; }
S() { sudo docker exec -i savannah-pg-standby psql -U postgres -d savannah_crest "$@"; }

echo "===== 1. Write on the primary, read on the standby ====="
P -c "INSERT INTO guests (first_name, last_name, phone) VALUES ('Replica', 'Test', '08099990000') RETURNING guest_id, first_name, last_name;"
sleep 1
echo "-- Reading the same guest on the STANDBY:"
S -c "SELECT guest_id, first_name, last_name FROM guests WHERE phone = '08099990000';"

echo "===== 2. The standby is read-only ====="
S -c "INSERT INTO guests (first_name, last_name, phone) VALUES ('Should', 'Fail', '08099990001');"

echo "===== 3. Replication lag after a large write (149,049 rows rewritten) ====="
P -c "UPDATE folio_charges SET amount = amount;"
P -c "SELECT state, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS not_yet_applied, write_lag, flush_lag, replay_lag FROM pg_stat_replication;"
sleep 3
echo "-- Three seconds later:"
P -c "SELECT state, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS not_yet_applied FROM pg_stat_replication;"

echo "===== 4. Failover: the primary goes down ====="
sudo docker stop savannah-pg-primary
echo "-- Standby still answers reads:"
S -c "SELECT count(*) AS reservations_still_readable FROM reservations;"
echo "-- But cannot take bookings yet:"
S -c "INSERT INTO guests (first_name, last_name, phone) VALUES ('Before', 'Promote', '08099990002');"
echo "-- Promote the standby to primary:"
S -c "SELECT pg_promote();"
sleep 3
S -c "SELECT pg_is_in_recovery() AS still_standby;"
echo "-- New primary takes a booking:"
S -c "INSERT INTO guests (first_name, last_name, phone) VALUES ('After', 'Failover', '08099990003') RETURNING guest_id, first_name, last_name;"

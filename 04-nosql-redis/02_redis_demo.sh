#!/usr/bin/env bash
# Savannah Crest Hotels: Redis demos (Portfolio 4)
R()   { sudo docker exec -i savannah-redis redis-cli --no-raw "$@"; }   # readable output
RAW() { sudo docker exec -i savannah-redis redis-cli "$@"; }            # plain values
SQL() { psql -U postgres -h localhost -d savannah_crest -At -c "$1"; }

echo "===== 1. Free Deluxe rooms at Jabi on 24 Dec: Redis vs PostgreSQL ====="
echo -n "Redis (read one key):      "; RAW GET avail:jabi:deluxe:2026-12-24
echo -n "PostgreSQL (run a query):  "; SQL "SELECT count(*) FROM rooms r WHERE property_id = 2 AND room_type_id = 2 AND status = 'Available' AND NOT EXISTS (SELECT 1 FROM reservation_rooms rr WHERE rr.room_id = r.room_id AND rr.active AND rr.stay @> DATE '2026-12-24')"

echo; echo "===== 2. Safe booking: take a room only if one is left (atomic Lua script) ====="
KEY=avail:asokoro:executive_suite:2026-12-24
START=$(RAW GET $KEY)
echo "Executive Suites free at Asokoro on 24 Dec: $START"
LUA="local v = tonumber(redis.call('GET', KEYS[1])) if v and v >= tonumber(ARGV[1]) then return redis.call('DECRBY', KEYS[1], ARGV[1]) else return -1 end"
for i in $(seq 1 $((START + 1))); do
  echo -n "Booking $i -> rooms left: "; RAW EVAL "$LUA" 1 $KEY 1
done
echo "(-1 = sold out, booking refused; the counter never goes below 0)"
RAW SET $KEY "$START" > /dev/null; echo "Counter restored to $START"

echo; echo "===== 3. Room hold that expires by itself (SET NX EX) ====="
HOLD=hold:jabi:room204:2026-12-24
RAW DEL $HOLD > /dev/null
echo -n "Agent A holds room 204 for 10 s: "; R SET $HOLD agentA NX EX 10
echo -n "Agent B tries the same room:     "; R SET $HOLD agentB NX EX 10
echo -n "Seconds left on A's hold:        "; R TTL $HOLD
echo "Agent A does not confirm. Waiting 11 seconds..."; sleep 11
echo -n "Hold after 11 seconds:           "; R GET $HOLD
echo -n "Agent B tries again:             "; R SET $HOLD agentB NX EX 10

echo; echo "===== 4. Guest profile (hash) ====="
R HGETALL guest:777

echo; echo "===== 5. Top 5 guests by spend: Redis sorted set vs SQL ====="
echo "Redis:"; R ZREVRANGE guests:net_spend 0 4 WITHSCORES
echo "SQL (guest | net spend):"
SQL "SELECT 'guest:' || r.guest_id || ' | ' || sum(CASE WHEN p.payment_type = 'Refund' THEN -p.amount ELSE p.amount END) FROM payments p JOIN reservations r USING (reservation_id) GROUP BY r.guest_id ORDER BY sum(CASE WHEN p.payment_type = 'Refund' THEN -p.amount ELSE p.amount END) DESC LIMIT 5"
echo -n "Guest 777's rank (0 = top):      "; R ZREVRANK guests:net_spend guest:777

echo; echo "===== 6. Speed and memory ====="
sudo docker exec savannah-redis redis-benchmark -q -n 100000 -t set,get 2>&1 | tr '\r' '\n' | grep "requests per second"
echo -n "Memory used by all 15,373 keys: "; RAW INFO memory | grep "^used_memory_human" | cut -d: -f2

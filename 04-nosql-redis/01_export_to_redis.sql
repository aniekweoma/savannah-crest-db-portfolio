-- Produces Redis commands (one per line) from PostgreSQL data
-- 1. Availability counters: free rooms per hotel, room type and night, December 2026
WITH nights AS (SELECT d::date AS night FROM generate_series(DATE '2026-12-01', DATE '2026-12-31', interval '1 day') d)
SELECT format('SET avail:%s:%s:%s %s', lower(p.district), replace(lower(t.name), ' ', '_'), n.night, count(r.room_id))
FROM nights n
CROSS JOIN properties p
CROSS JOIN room_types t
LEFT JOIN rooms r ON r.property_id = p.property_id AND r.room_type_id = t.room_type_id
  AND r.status = 'Available'
  AND NOT EXISTS (SELECT 1 FROM reservation_rooms rr
                  WHERE rr.room_id = r.room_id AND rr.active AND rr.stay @> n.night)
GROUP BY p.district, t.name, n.night;

-- 2. Guest profiles as hashes
SELECT format('HSET guest:%s name "%s %s" phone %s nationality "%s" tier %s',
              guest_id, first_name, last_name, phone, nationality, loyalty_tier)
FROM guests;

-- 3. Ranking of guests by net spend (sorted set)
SELECT format('ZADD guests:net_spend %s "%s"', sum(CASE WHEN p.payment_type = 'Refund' THEN -p.amount ELSE p.amount END),
              'guest:' || r.guest_id)
FROM payments p JOIN reservations r USING (reservation_id)
GROUP BY r.guest_id;

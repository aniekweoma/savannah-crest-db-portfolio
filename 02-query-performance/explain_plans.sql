-- Savannah Crest Hotels: execution plans (run before and after optimisation)
SELECT phone AS gphone FROM guests WHERE guest_id = 777 \gset
SELECT reservation_id AS fres FROM folio_charges GROUP BY reservation_id ORDER BY count(*) DESC, reservation_id LIMIT 1 \gset

\echo '=== H1: Availability search ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.room_number FROM rooms r JOIN room_types t USING (room_type_id)
WHERE r.property_id = 2 AND t.name = 'Deluxe' AND r.status = 'Available'
  AND NOT EXISTS (SELECT 1 FROM reservation_rooms rr WHERE rr.room_id = r.room_id AND rr.active
                  AND rr.stay && daterange('2026-12-20', '2026-12-23'));

\echo '=== H2: Guest history by phone ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.reservation_id, r.check_in, r.status
FROM guests g JOIN reservations r USING (guest_id)
WHERE g.phone = :'gphone';

\echo '=== H3: Tomorrow''s arrivals ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.reservation_id, r.guest_id
FROM reservations r
WHERE r.property_id = 2 AND r.check_in = DATE '2026-10-29' AND r.status = 'Confirmed';

\echo '=== H4: Bill total ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*), sum(amount) FROM folio_charges WHERE reservation_id = :fres;

\echo '=== H5: Monthly occupancy report ==='
EXPLAIN (ANALYZE, BUFFERS)
WITH months AS (
  SELECT daterange(d::date, (d + interval '1 month')::date) AS m
  FROM generate_series(DATE '2025-01-01', DATE '2025-12-01', interval '1 month') d)
SELECT r.property_id, lower(mo.m), sum(upper(rr.stay * mo.m) - lower(rr.stay * mo.m))
FROM months mo
JOIN reservation_rooms rr ON rr.active AND rr.stay && mo.m
JOIN rooms r ON r.room_id = rr.room_id
GROUP BY 1, 2;

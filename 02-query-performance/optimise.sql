-- Savannah Crest Hotels: optimisation (Portfolio 2)

-- H2: guest lookup by phone, then their reservations
CREATE INDEX idx_guests_phone ON guests (phone);
CREATE INDEX idx_reservations_guest ON reservations (guest_id);

-- H3: PARTIAL index: only confirmed (upcoming) bookings, which are a small
-- share of all reservations, so the index stays tiny
CREATE INDEX idx_arrivals_confirmed ON reservations (property_id, check_in)
  WHERE status = 'Confirmed';

-- H4: COVERING index: INCLUDE (amount) stores the amount inside the index,
-- so the bill total can be answered without reading the table (index-only scan)
CREATE INDEX idx_folio_reservation_cov ON folio_charges (reservation_id) INCLUDE (amount);

-- H5: MATERIALISED VIEW: monthly occupancy for every hotel and month, stored
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_occupancy;
CREATE MATERIALIZED VIEW mv_monthly_occupancy AS
WITH months AS (
  SELECT d::date AS month_start, daterange(d::date, (d + interval '1 month')::date) AS m
  FROM generate_series(DATE '2022-01-01', DATE '2026-12-01', interval '1 month') d),
capacity AS (SELECT property_id, count(*) AS rooms FROM rooms GROUP BY property_id)
SELECT r.property_id, mo.month_start AS month,
       sum(upper(rr.stay * mo.m) - lower(rr.stay * mo.m))::int AS nights_sold,
       (c.rooms * (upper(mo.m) - lower(mo.m)))::int AS room_nights,
       round(100.0 * sum(upper(rr.stay * mo.m) - lower(rr.stay * mo.m))
             / (c.rooms * (upper(mo.m) - lower(mo.m))), 1) AS occupancy_pct
FROM months mo
JOIN reservation_rooms rr ON rr.active AND rr.stay && mo.m
JOIN rooms r ON r.room_id = rr.room_id
JOIN capacity c ON c.property_id = r.property_id
GROUP BY r.property_id, mo.month_start, mo.m, c.rooms;

-- A unique index lets the view be refreshed without blocking readers
CREATE UNIQUE INDEX ON mv_monthly_occupancy (property_id, month);

-- Update statistics and the visibility map (needed for index-only scans)
VACUUM ANALYZE;

\echo '=== Refreshing the materialised view (cost of keeping it current) ==='
\timing on
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_occupancy;
\timing off

\echo '=== Sizes of the new structures ==='
SELECT c.relname AS name,
       CASE c.relkind WHEN 'i' THEN 'index' WHEN 'm' THEN 'materialised view' END AS kind,
       pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM pg_class c
WHERE c.relname IN ('idx_guests_phone', 'idx_reservations_guest', 'idx_arrivals_confirmed',
                    'idx_folio_reservation_cov', 'mv_monthly_occupancy', 'no_double_booking')
ORDER BY pg_relation_size(c.oid) DESC;

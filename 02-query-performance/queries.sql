-- Savannah Crest Hotels: business queries (Portfolio 2)
\timing on
SELECT phone AS gphone FROM guests WHERE guest_id = 777 \gset
SELECT reservation_id AS fres FROM folio_charges GROUP BY reservation_id ORDER BY count(*) DESC, reservation_id LIMIT 1 \gset

\echo '=== H1: Free Deluxe rooms at Jabi, 20-23 Dec 2026 ==='
SELECT r.room_number, r.floor
FROM rooms r
JOIN room_types t USING (room_type_id)
WHERE r.property_id = 2 AND t.name = 'Deluxe' AND r.status = 'Available'
  AND NOT EXISTS (SELECT 1 FROM reservation_rooms rr
                  WHERE rr.room_id = r.room_id AND rr.active
                    AND rr.stay && daterange('2026-12-20', '2026-12-23'))
ORDER BY r.room_number;

\echo '=== H2: Stay history of a returning guest, searched by phone ==='
SELECT r.reservation_id, p.name AS hotel, r.check_in, r.check_out, r.status, r.channel
FROM guests g
JOIN reservations r USING (guest_id)
JOIN properties p ON p.property_id = r.property_id
WHERE g.phone = :'gphone'
ORDER BY r.check_in DESC;

\echo '=== H3: Tomorrow''s confirmed arrivals at Jabi ==='
SELECT r.reservation_id, g.first_name || ' ' || g.last_name AS guest, rm.room_number,
       r.adults, r.children, r.channel
FROM reservations r
JOIN guests g ON g.guest_id = r.guest_id
JOIN reservation_rooms rr ON rr.reservation_id = r.reservation_id
JOIN rooms rm ON rm.room_id = rr.room_id
WHERE r.property_id = 2 AND r.check_in = DATE '2026-10-29' AND r.status = 'Confirmed'
ORDER BY rm.room_number;

\echo '=== H4: Bill total for one reservation ==='
SELECT count(*) AS charges, sum(amount) AS total_extras_ngn
FROM folio_charges WHERE reservation_id = :fres;

\echo '=== H5: Occupancy % per hotel per month, 2025 ==='
WITH months AS (
  SELECT daterange(d::date, (d + interval '1 month')::date) AS m
  FROM generate_series(DATE '2025-01-01', DATE '2025-12-01', interval '1 month') d),
capacity AS (SELECT property_id, count(*) AS rooms FROM rooms GROUP BY property_id)
SELECT p.name AS hotel, to_char(lower(mo.m), 'Mon') AS month,
       sum(upper(rr.stay * mo.m) - lower(rr.stay * mo.m)) AS nights_sold,
       round(100.0 * sum(upper(rr.stay * mo.m) - lower(rr.stay * mo.m))
             / (c.rooms * (upper(mo.m) - lower(mo.m))), 1) AS occupancy_pct
FROM months mo
JOIN reservation_rooms rr ON rr.active AND rr.stay && mo.m
JOIN rooms r ON r.room_id = rr.room_id
JOIN properties p ON p.property_id = r.property_id
JOIN capacity c ON c.property_id = r.property_id
GROUP BY p.name, mo.m, c.rooms
ORDER BY p.name, lower(mo.m);

\echo '=== H6: ADR and RevPAR per hotel, 2025, with total row ==='
WITH yr AS (SELECT daterange('2025-01-01', '2026-01-01') AS y),
sold AS (
  SELECT r.property_id, sum(upper(rr.stay * yr.y) - lower(rr.stay * yr.y)) AS nights,
         sum((upper(rr.stay * yr.y) - lower(rr.stay * yr.y)) * rr.nightly_rate) AS revenue
  FROM reservation_rooms rr JOIN rooms r USING (room_id) CROSS JOIN yr
  WHERE rr.active AND rr.stay && yr.y
  GROUP BY r.property_id),
avail AS (SELECT property_id, count(*) * 365 AS room_nights FROM rooms GROUP BY property_id)
SELECT COALESCE(p.name, 'ALL HOTELS') AS hotel,
       sum(s.nights) AS nights_sold,
       round(100.0 * sum(s.nights) / sum(a.room_nights), 1) AS occupancy_pct,
       round(sum(s.revenue) / sum(s.nights)) AS adr_ngn,
       round(sum(s.revenue) / sum(a.room_nights)) AS revpar_ngn
FROM sold s JOIN avail a USING (property_id) JOIN properties p USING (property_id)
GROUP BY ROLLUP (p.name)
ORDER BY p.name NULLS LAST;

\echo '=== H7: Extras revenue by hotel and category, 2025 ==='
SELECT COALESCE(p.name, 'ALL HOTELS') AS hotel, COALESCE(s.category, '(all categories)') AS category,
       sum(fc.amount) AS revenue_ngn
FROM folio_charges fc
JOIN services s ON s.service_id = fc.service_id
JOIN reservations r ON r.reservation_id = fc.reservation_id
JOIN properties p ON p.property_id = r.property_id
WHERE fc.charged_at >= '2025-01-01' AND fc.charged_at < '2026-01-01'
GROUP BY GROUPING SETS ((p.name, s.category), (p.name), ())
ORDER BY p.name NULLS LAST, s.category NULLS LAST;

\echo '=== H8: Top 10 guests by net spend ==='
SELECT g.first_name || ' ' || g.last_name AS guest, g.nationality, g.loyalty_tier,
       count(DISTINCT r.reservation_id) AS paid_bookings,
       sum(CASE WHEN pay.payment_type = 'Refund' THEN -pay.amount ELSE pay.amount END) AS net_spend_ngn,
       RANK() OVER (ORDER BY sum(CASE WHEN pay.payment_type = 'Refund' THEN -pay.amount ELSE pay.amount END) DESC) AS rank
FROM guests g
JOIN reservations r ON r.guest_id = g.guest_id
JOIN payments pay ON pay.reservation_id = r.reservation_id
GROUP BY g.guest_id
ORDER BY rank
LIMIT 10;

\echo '=== H9: Year-on-year revenue growth per hotel ==='
WITH yearly AS (
  SELECT r.property_id, extract(year FROM pay.paid_at)::int AS year,
         sum(CASE WHEN pay.payment_type = 'Refund' THEN -pay.amount ELSE pay.amount END) AS revenue
  FROM payments pay JOIN reservations r ON r.reservation_id = pay.reservation_id
  GROUP BY 1, 2)
SELECT p.name AS hotel, y.year, y.revenue AS revenue_ngn,
       round(100.0 * (y.revenue - LAG(y.revenue) OVER w) / LAG(y.revenue) OVER w, 1) AS growth_pct
FROM yearly y JOIN properties p USING (property_id)
WHERE y.year BETWEEN 2022 AND 2025
WINDOW w AS (PARTITION BY p.name ORDER BY y.year)
ORDER BY p.name, y.year;

\echo '=== H10: Booking lead time by channel (days between booking and arrival) ==='
SELECT channel, count(*) AS bookings,
       round(avg(check_in - booked_at::date), 1) AS avg_days,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY check_in - booked_at::date) AS median_days
FROM reservations
GROUP BY channel
ORDER BY avg_days DESC;

-- Savannah Crest Hotels: integrity test harness
-- Each test runs in its own sub-transaction and is marked PASS or FAIL.
-- Everything is rolled back at the end.
BEGIN;

CREATE TEMP TABLE test_results (
  test_no int, description text, expected text, actual text, result text, detail text);

CREATE FUNCTION pg_temp.run_test(n int, descr text, expect_ok boolean, stmt text)
RETURNS void AS $$
DECLARE ok boolean; msg text := '';
BEGIN
  BEGIN
    EXECUTE stmt;
    ok := true;
  EXCEPTION WHEN OTHERS THEN
    ok := false; msg := SQLERRM;
  END;
  INSERT INTO test_results VALUES (n, descr,
    CASE WHEN expect_ok THEN 'Accept' ELSE 'Reject' END,
    CASE WHEN ok THEN 'Accepted' ELSE 'Rejected' END,
    CASE WHEN ok = expect_ok THEN 'PASS' ELSE 'FAIL' END, msg);
END $$ LANGUAGE plpgsql;

-- ---------- Setup data ----------
INSERT INTO properties (name, district, address, star_rating) VALUES
  ('Savannah Crest Asokoro', 'Asokoro', '12 Yakubu Gowon Crescent, Asokoro', 5),
  ('Savannah Crest Jabi',    'Jabi',    '5 Obafemi Awolowo Way, Jabi',       4);
INSERT INTO room_types (name, max_occupancy, base_rate) VALUES ('Deluxe', 2, 85000);
INSERT INTO rooms (property_id, room_type_id, room_number, floor)
SELECT p.property_id, t.room_type_id, v.num, v.fl
FROM (VALUES ('Savannah Crest Jabi', '204', 2), ('Savannah Crest Asokoro', '101', 1)) v(hotel, num, fl)
JOIN properties p ON p.name = v.hotel CROSS JOIN room_types t;
INSERT INTO guests (first_name, last_name, phone, email) VALUES
  ('Ngozi', 'Eze', '08031112222', 'ngozi.eze@example.com'),
  ('Bayo',  'Adeleke', '08034445555', 'bayo.adeleke@example.com');

SELECT property_id AS jabi FROM properties WHERE name = 'Savannah Crest Jabi' \gset
SELECT room_type_id AS deluxe FROM room_types WHERE name = 'Deluxe' \gset
SELECT room_id AS room204 FROM rooms WHERE room_number = '204' \gset
SELECT room_id AS room101 FROM rooms WHERE room_number = '101' \gset

INSERT INTO reservations (guest_id, property_id, channel, check_in, check_out)
SELECT guest_id, :jabi, 'Website', '2026-12-20', '2026-12-23' FROM guests WHERE first_name = 'Ngozi'
RETURNING reservation_id AS r1 \gset
INSERT INTO reservations (guest_id, property_id, channel, check_in, check_out)
SELECT guest_id, :jabi, 'Phone', '2026-12-21', '2026-12-23' FROM guests WHERE first_name = 'Bayo'
RETURNING reservation_id AS r2 \gset
INSERT INTO reservations (guest_id, property_id, channel, check_in, check_out)
SELECT guest_id, :jabi, 'Walk-in', '2026-12-23', '2026-12-25' FROM guests WHERE first_name = 'Bayo'
RETURNING reservation_id AS r3 \gset

-- ---------- Tests ----------
\o /dev/null
SELECT pg_temp.run_test(1, 'Ngozi books room 204 for 20-23 Dec', true,
  format('INSERT INTO reservation_rooms (reservation_id, room_id, stay, nightly_rate) VALUES (%s, %s, ''[2026-12-20,2026-12-23)'', 85000)', :r1, :room204));
SELECT pg_temp.run_test(2, 'Bayo books room 204 for 21-23 Dec (overlap)', false,
  format('INSERT INTO reservation_rooms (reservation_id, room_id, stay, nightly_rate) VALUES (%s, %s, ''[2026-12-21,2026-12-23)'', 85000)', :r2, :room204));
SELECT pg_temp.run_test(3, 'Bayo books room 204 for 23-25 Dec (check-in on checkout day)', true,
  format('INSERT INTO reservation_rooms (reservation_id, room_id, stay, nightly_rate) VALUES (%s, %s, ''[2026-12-23,2026-12-25)'', 85000)', :r3, :room204));
SELECT pg_temp.run_test(4, 'Ngozi cancels: trigger frees her room', true,
  format('UPDATE reservations SET status = ''Cancelled'' WHERE reservation_id = %s', :r1));
SELECT pg_temp.run_test(5, 'Bayo retries room 204 for 21-23 Dec after cancellation', true,
  format('INSERT INTO reservation_rooms (reservation_id, room_id, stay, nightly_rate) VALUES (%s, %s, ''[2026-12-21,2026-12-23)'', 85000)', :r2, :room204));
SELECT pg_temp.run_test(6, 'Jabi booking takes an Asokoro room', false,
  format('INSERT INTO reservation_rooms (reservation_id, room_id, stay, nightly_rate) VALUES (%s, %s, ''[2026-12-23,2026-12-25)'', 85000)', :r3, :room101));
SELECT pg_temp.run_test(7, 'Check-out before check-in', false,
  format('INSERT INTO reservations (guest_id, property_id, channel, check_in, check_out) VALUES ((SELECT guest_id FROM guests WHERE first_name = ''Ngozi''), %s, ''Phone'', ''2026-12-25'', ''2026-12-24'')', :jabi));
SELECT pg_temp.run_test(8, 'Christmas peak rate 15 Dec - 5 Jan', true,
  format('INSERT INTO seasonal_rates (property_id, room_type_id, season_name, valid_period, nightly_rate) VALUES (%s, %s, ''Christmas Peak'', ''[2026-12-15,2027-01-05)'', 120000)', :jabi, :deluxe));
SELECT pg_temp.run_test(9, 'Overlapping New Year rate 30 Dec - 10 Jan', false,
  format('INSERT INTO seasonal_rates (property_id, room_type_id, season_name, valid_period, nightly_rate) VALUES (%s, %s, ''New Year'', ''[2026-12-30,2027-01-10)'', 110000)', :jabi, :deluxe));
SELECT pg_temp.run_test(10, 'Invalid loyalty tier (Diamond)', false,
  'INSERT INTO guests (first_name, last_name, phone, loyalty_tier) VALUES (''Tola'', ''Bello'', ''08030000000'', ''Diamond'')');
SELECT pg_temp.run_test(11, 'Duplicate room number 204 at Jabi', false,
  format('INSERT INTO rooms (property_id, room_type_id, room_number, floor) VALUES (%s, %s, ''204'', 2)', :jabi, :deluxe));
SELECT pg_temp.run_test(12, 'Payment of zero naira', false,
  format('INSERT INTO payments (reservation_id, amount, method, payment_type) VALUES (%s, 0, ''Cash'', ''Deposit'')', :r3));
\o

-- ---------- Report ----------
\echo '========== INTEGRITY TEST REPORT =========='
SELECT test_no AS "#", description, expected, actual, result, left(detail, 60) AS database_message
FROM test_results ORDER BY test_no;

SELECT count(*) FILTER (WHERE result = 'PASS') AS passed,
       count(*) FILTER (WHERE result = 'FAIL') AS failed
FROM test_results;

\echo '========== ROOM 204 BOOKINGS (final state) =========='
SELECT rr.reservation_id, g.first_name AS guest, rr.stay, rr.active, r.status
FROM reservation_rooms rr
JOIN reservations r USING (reservation_id)
JOIN guests g USING (guest_id)
ORDER BY lower(rr.stay), rr.reservation_id;

ROLLBACK;

-- Check-out workflow: 3 steps that must succeed or fail together
SELECT reservation_id AS res_ok, property_id AS prop_ok FROM reservations
WHERE status = 'Checked-in' ORDER BY reservation_id LIMIT 1 \gset
SELECT reservation_id AS res_bad, property_id AS prop_bad FROM reservations
WHERE status = 'Checked-in' ORDER BY reservation_id OFFSET 1 LIMIT 1 \gset

\echo '########## A: CHECK-OUT THAT SUCCEEDS (COMMIT) ##########'
SELECT reservation_id, status FROM reservations WHERE reservation_id = :res_ok;
BEGIN;
-- 1. Post the last dinner to the bill
INSERT INTO folio_charges (reservation_id, service_id, posted_by, quantity, amount)
VALUES (:res_ok, 2, (SELECT staff_id FROM staff WHERE property_id = :prop_ok AND role = 'Service' LIMIT 1), 1, 15000);
-- 2. Take the balance: room + extras - deposit
INSERT INTO payments (reservation_id, amount, method, payment_type)
SELECT :res_ok,
       (SELECT sum(nightly_rate * (upper(stay) - lower(stay))) FROM reservation_rooms WHERE reservation_id = :res_ok)
     + (SELECT COALESCE(sum(amount), 0) FROM folio_charges WHERE reservation_id = :res_ok)
     - (SELECT COALESCE(sum(amount), 0) FROM payments WHERE reservation_id = :res_ok AND payment_type = 'Deposit'),
       'POS', 'Balance';
-- 3. Mark the guest as checked out
UPDATE reservations SET status = 'Checked-out' WHERE reservation_id = :res_ok;
COMMIT;
SELECT r.reservation_id, r.status,
       (SELECT amount FROM payments WHERE reservation_id = r.reservation_id AND payment_type = 'Balance') AS balance_paid
FROM reservations r WHERE r.reservation_id = :res_ok;

\echo '########## B: CHECK-OUT THAT FAILS (ROLLBACK) ##########'
SELECT reservation_id, status,
       (SELECT count(*) FROM folio_charges WHERE reservation_id = :res_bad) AS charges
FROM reservations WHERE reservation_id = :res_bad;
BEGIN;
INSERT INTO folio_charges (reservation_id, service_id, posted_by, quantity, amount)
VALUES (:res_bad, 2, (SELECT staff_id FROM staff WHERE property_id = :prop_bad AND role = 'Service' LIMIT 1), 1, 15000);
-- Payment method 'Crypto' is not allowed: this step fails
INSERT INTO payments (reservation_id, amount, method, payment_type)
VALUES (:res_bad, 50000, 'Crypto', 'Balance');
-- Refused: the transaction is already broken
UPDATE reservations SET status = 'Checked-out' WHERE reservation_id = :res_bad;
ROLLBACK;
\echo '--- After ROLLBACK: status and charge count unchanged ---'
SELECT reservation_id, status,
       (SELECT count(*) FROM folio_charges WHERE reservation_id = :res_bad) AS charges
FROM reservations WHERE reservation_id = :res_bad;

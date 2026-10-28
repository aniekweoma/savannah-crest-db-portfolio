-- Setup for the write-skew demo (safe to re-run)
DELETE FROM reservations WHERE check_in = DATE '2027-02-14';
DROP TABLE IF EXISTS demo_ids;
CREATE TABLE demo_ids (label text PRIMARY KEY, id int);

-- The two Deluxe rooms at Jabi that will stay free
INSERT INTO demo_ids
SELECT 'room_' || chr(64 + rn::int), room_id FROM (
  SELECT room_id, row_number() OVER (ORDER BY room_number) AS rn
  FROM rooms WHERE property_id = 2 AND room_type_id = 2 AND status = 'Available') d
WHERE rn <= 2;

-- A corporate group takes every other Deluxe room that night
INSERT INTO reservations (guest_id, property_id, channel, check_in, check_out)
VALUES (1, 2, 'Phone', '2027-02-14', '2027-02-15') RETURNING reservation_id AS block \gset
INSERT INTO reservation_rooms (reservation_id, room_id, stay, nightly_rate)
SELECT :block, room_id, '[2027-02-14,2027-02-15)', 65000
FROM rooms WHERE property_id = 2 AND room_type_id = 2 AND status = 'Available'
  AND room_id NOT IN (SELECT id FROM demo_ids);

-- Two agents each have a guest waiting for a room
INSERT INTO reservations (guest_id, property_id, channel, check_in, check_out)
VALUES (2, 2, 'Website', '2027-02-14', '2027-02-15') RETURNING reservation_id AS ra \gset
INSERT INTO reservations (guest_id, property_id, channel, check_in, check_out)
VALUES (3, 2, 'Phone', '2027-02-14', '2027-02-15') RETURNING reservation_id AS rb \gset
INSERT INTO demo_ids VALUES ('res_A', :ra), ('res_B', :rb);

-- The check both agents run before booking
CREATE OR REPLACE VIEW free_deluxe_valentines AS
SELECT count(*) AS free_rooms FROM rooms r
WHERE property_id = 2 AND room_type_id = 2 AND status = 'Available'
  AND NOT EXISTS (SELECT 1 FROM reservation_rooms rr
                  WHERE rr.room_id = r.room_id AND rr.active
                    AND rr.stay && daterange('2027-02-14', '2027-02-15'));

SELECT * FROM free_deluxe_valentines;
SELECT * FROM demo_ids ORDER BY label;

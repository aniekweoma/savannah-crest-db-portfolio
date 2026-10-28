-- Savannah Crest Hotels: load generated CSV data (run after generate_data.py)
TRUNCATE payments, folio_charges, services, reservation_rooms, reservations, staff,
  guests, seasonal_rates, rooms, room_types, properties RESTART IDENTITY CASCADE;

INSERT INTO properties (name, district, address, star_rating, phone) VALUES
  ('Savannah Crest Asokoro',  'Asokoro',  '12 Yakubu Gowon Crescent, Asokoro, Abuja', 5, '09087654301'),
  ('Savannah Crest Jabi',     'Jabi',     '5 Obafemi Awolowo Way, Jabi, Abuja',       4, '09087654302'),
  ('Savannah Crest Gwarinpa', 'Gwarinpa', '23 1st Avenue, Gwarinpa, Abuja',           3, '09087654303');

INSERT INTO room_types (name, max_occupancy, base_rate, description) VALUES
  ('Standard',        2,  45000, 'Queen bed, work desk'),
  ('Deluxe',          2,  65000, 'King bed, city view'),
  ('Executive Suite', 3, 120000, 'Separate lounge, executive lounge access'),
  ('Family Room',     4,  90000, 'Two double beds');

INSERT INTO services (name, category, unit_price) VALUES
  ('Breakfast Buffet', 'Food & Beverage',  8000),
  ('Dinner',           'Food & Beverage', 15000),
  ('Room Service',     'Food & Beverage',  6000),
  ('Laundry (per item)', 'Laundry',        2500),
  ('Spa Massage',      'Wellness',        25000),
  ('Airport Pickup',   'Transport',       20000),
  ('Minibar',          'Food & Beverage',  5000);

\copy rooms (property_id, room_type_id, room_number, floor, status) FROM '/tmp/savannah_crest_data/rooms.csv' WITH (FORMAT csv)
\copy seasonal_rates (property_id, room_type_id, season_name, valid_period, nightly_rate) FROM '/tmp/savannah_crest_data/seasonal_rates.csv' WITH (FORMAT csv)
\copy guests (first_name, last_name, email, phone, nationality, id_type, id_number, loyalty_tier, created_at) FROM '/tmp/savannah_crest_data/guests.csv' WITH (FORMAT csv)
\copy staff (property_id, first_name, last_name, role, email, hired_on) FROM '/tmp/savannah_crest_data/staff.csv' WITH (FORMAT csv)
\copy reservations (guest_id, property_id, channel, status, check_in, check_out, adults, children, booked_at) FROM '/tmp/savannah_crest_data/reservations.csv' WITH (FORMAT csv)
\copy reservation_rooms (reservation_id, room_id, stay, nightly_rate, active) FROM '/tmp/savannah_crest_data/reservation_rooms.csv' WITH (FORMAT csv)
\copy folio_charges (reservation_id, service_id, posted_by, quantity, amount, charged_at) FROM '/tmp/savannah_crest_data/folio_charges.csv' WITH (FORMAT csv)
\copy payments (reservation_id, amount, method, payment_type, paid_at) FROM '/tmp/savannah_crest_data/payments.csv' WITH (FORMAT csv)

ANALYZE;

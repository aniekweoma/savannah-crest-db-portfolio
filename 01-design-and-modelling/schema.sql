-- Savannah Crest Hotels: relational schema (PostgreSQL 17)

CREATE EXTENSION IF NOT EXISTS btree_gist;   -- lets exclusion constraints combine = and && operators

DROP TABLE IF EXISTS payments, folio_charges, services, reservation_rooms,
  reservations, staff, guests, seasonal_rates, rooms, room_types, properties CASCADE;

CREATE TABLE properties (
  property_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name         VARCHAR(80)  NOT NULL UNIQUE,
  district     VARCHAR(40)  NOT NULL,
  address      VARCHAR(200) NOT NULL,
  star_rating  SMALLINT     NOT NULL CHECK (star_rating BETWEEN 1 AND 5),
  phone        VARCHAR(20)
);

CREATE TABLE room_types (
  room_type_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          VARCHAR(40)   NOT NULL UNIQUE,
  max_occupancy SMALLINT      NOT NULL CHECK (max_occupancy BETWEEN 1 AND 6),
  base_rate     NUMERIC(12,2) NOT NULL CHECK (base_rate > 0),
  description   TEXT
);

CREATE TABLE rooms (
  room_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  property_id  INT NOT NULL REFERENCES properties,
  room_type_id INT NOT NULL REFERENCES room_types,
  room_number  VARCHAR(10) NOT NULL,
  floor        SMALLINT    NOT NULL CHECK (floor >= 0),
  status       VARCHAR(20) NOT NULL DEFAULT 'Available'
               CHECK (status IN ('Available', 'Maintenance', 'Out of Service')),
  UNIQUE (property_id, room_number)
);

-- Seasonal prices: two price periods for the same hotel and room type may not overlap
CREATE TABLE seasonal_rates (
  rate_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  property_id  INT NOT NULL REFERENCES properties,
  room_type_id INT NOT NULL REFERENCES room_types,
  season_name  VARCHAR(40)   NOT NULL,
  valid_period DATERANGE     NOT NULL CHECK (NOT isempty(valid_period)),
  nightly_rate NUMERIC(12,2) NOT NULL CHECK (nightly_rate > 0),
  CONSTRAINT no_overlapping_rates
    EXCLUDE USING gist (property_id WITH =, room_type_id WITH =, valid_period WITH &&)
);

CREATE TABLE guests (
  guest_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  first_name   VARCHAR(50)  NOT NULL,
  last_name    VARCHAR(50)  NOT NULL,
  email        VARCHAR(120) UNIQUE,
  phone        VARCHAR(20)  NOT NULL,
  nationality  VARCHAR(40)  NOT NULL DEFAULT 'Nigerian',
  id_type      VARCHAR(20)  CHECK (id_type IN ('NIN', 'Passport', 'Driver Licence', 'Voter Card')),
  id_number    VARCHAR(30),
  loyalty_tier VARCHAR(10)  NOT NULL DEFAULT 'None'
               CHECK (loyalty_tier IN ('None', 'Silver', 'Gold', 'Platinum')),
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE staff (
  staff_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  property_id INT NOT NULL REFERENCES properties,
  first_name  VARCHAR(50) NOT NULL,
  last_name   VARCHAR(50) NOT NULL,
  role        VARCHAR(20) NOT NULL
              CHECK (role IN ('Front Desk', 'Reservations', 'Housekeeping', 'Service', 'Accounts', 'Manager')),
  email       VARCHAR(120) UNIQUE,
  hired_on    DATE NOT NULL
);

CREATE TABLE reservations (
  reservation_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  guest_id       INT NOT NULL REFERENCES guests,
  property_id    INT NOT NULL REFERENCES properties,
  channel        VARCHAR(10) NOT NULL CHECK (channel IN ('Website', 'Phone', 'Walk-in', 'OTA')),
  status         VARCHAR(12) NOT NULL DEFAULT 'Confirmed'
                 CHECK (status IN ('Confirmed', 'Checked-in', 'Checked-out', 'Cancelled', 'No-show')),
  check_in       DATE NOT NULL,
  check_out      DATE NOT NULL,
  adults         SMALLINT NOT NULL DEFAULT 1 CHECK (adults >= 1),
  children       SMALLINT NOT NULL DEFAULT 0 CHECK (children >= 0),
  booked_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT valid_stay_dates CHECK (check_out > check_in)
);

-- Which rooms a reservation holds, and for which nights.
-- A room may never have two ACTIVE stays with overlapping nights.
CREATE TABLE reservation_rooms (
  reservation_id INT NOT NULL REFERENCES reservations ON DELETE CASCADE,
  room_id        INT NOT NULL REFERENCES rooms,
  stay           DATERANGE     NOT NULL CHECK (NOT isempty(stay)),
  nightly_rate   NUMERIC(12,2) NOT NULL CHECK (nightly_rate > 0),
  active         BOOLEAN       NOT NULL DEFAULT true,
  PRIMARY KEY (reservation_id, room_id),
  CONSTRAINT no_double_booking
    EXCLUDE USING gist (room_id WITH =, stay WITH &&) WHERE (active)
);

CREATE TABLE services (
  service_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(60) NOT NULL UNIQUE,
  category   VARCHAR(20) NOT NULL
             CHECK (category IN ('Food & Beverage', 'Laundry', 'Wellness', 'Transport')),
  unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE folio_charges (
  charge_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reservation_id INT NOT NULL REFERENCES reservations,
  service_id     INT NOT NULL REFERENCES services,
  posted_by      INT NOT NULL REFERENCES staff,
  quantity       SMALLINT      NOT NULL DEFAULT 1 CHECK (quantity > 0),
  amount         NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  charged_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE payments (
  payment_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reservation_id INT NOT NULL REFERENCES reservations,
  amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  method         VARCHAR(10) NOT NULL CHECK (method IN ('Card', 'Transfer', 'Cash', 'POS')),
  payment_type   VARCHAR(10) NOT NULL CHECK (payment_type IN ('Deposit', 'Balance', 'Refund')),
  paid_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger 1: a booked room must belong to the same hotel as the reservation
CREATE OR REPLACE FUNCTION check_room_property() RETURNS trigger AS $$
BEGIN
  IF (SELECT property_id FROM rooms WHERE room_id = NEW.room_id)
     <> (SELECT property_id FROM reservations WHERE reservation_id = NEW.reservation_id) THEN
    RAISE EXCEPTION 'Room % does not belong to the hotel of reservation %',
      NEW.room_id, NEW.reservation_id;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_room_property
  BEFORE INSERT OR UPDATE ON reservation_rooms
  FOR EACH ROW EXECUTE FUNCTION check_room_property();

-- Trigger 2: cancelling a reservation (or a no-show) automatically frees its rooms
CREATE OR REPLACE FUNCTION release_rooms() RETURNS trigger AS $$
BEGIN
  UPDATE reservation_rooms SET active = false
  WHERE reservation_id = NEW.reservation_id;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_release_rooms
  AFTER UPDATE OF status ON reservations
  FOR EACH ROW WHEN (NEW.status IN ('Cancelled', 'No-show'))
  EXECUTE FUNCTION release_rooms();

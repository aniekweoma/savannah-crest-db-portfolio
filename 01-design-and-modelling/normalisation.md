# Normalisation: Savannah Crest Hotels

## Starting point: the front-desk booking spreadsheet

Before the database, each property kept one spreadsheet row per booking:

| BookingRef | GuestName | GuestPhone | GuestEmail | Hotel | HotelAddress | Rooms | RoomTypes | CheckIn | CheckOut | RatePerNight | Extras | AmountPaid |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| SC-1042 | Ngozi Eze | 0803... | ngozi@... | Savannah Crest Jabi | Plot 5, Jabi | 204, 205 | Deluxe, Deluxe | 2026-12-20 | 2026-12-23 | 85000 | Dinner x2; Laundry x1 | 300000 |

**Anomalies this causes:**
- **Update:** a returning guest's phone is stored in every booking row, so changing it means editing many rows.
- **Insertion:** a new room cannot be recorded until someone books it.
- **Deletion:** deleting a guest's only booking also deletes the only record of that guest.
- **Overlap:** nothing stops room 204 being typed into two bookings for the same nights.

## Functional dependencies identified

| Dependency | Meaning |
|---|---|
| `guest_id → first_name, last_name, phone, email, loyalty_tier` | A guest's details depend only on the guest |
| `property_id → name, district, address, star_rating` | A hotel's details depend only on the hotel |
| `room_id → property_id, room_type_id, room_number, floor` | A room belongs to one hotel and has one type |
| `room_type_id → name, max_occupancy, base_rate` | Type details depend only on the type |
| `reservation_id → guest_id, property_id, channel, status, check_in, check_out` | Booking-level facts |
| `(reservation_id, room_id) → stay, nightly_rate, active` | Facts about one room within one booking |
| `service_id → name, category, unit_price` | Service details depend only on the service |
| `(property_id, room_type_id, date) → nightly_rate` | The price for a night depends on hotel, type and season |

## 1NF: atomic values

`Rooms`, `RoomTypes` and `Extras` hold lists. Each list item became its own row:
- each room in a booking → a row in `reservation_rooms`;
- each extra → a row in `folio_charges`;
- names split into first and last name.

## 2NF: no partial dependencies

In `reservation_rooms`, the key is `(reservation_id, room_id)`. A room's type and floor depend only on `room_id` (part of the key), so they live in `rooms`, not in `reservation_rooms`. Only `stay`, `nightly_rate` and `active` depend on the **whole** key.

## 3NF and BCNF: no transitive dependencies

`reservation_id → property_id → address` is transitive, so the address lives in `properties`, and reservations store only `property_id`. The same applies to guests, room types and services. In every final table, every determinant is a candidate key, so the schema is in **BCNF**.

## Deliberate decisions

| Decision | Why it is not redundancy |
|---|---|
| `reservation_rooms.nightly_rate` copies a price | It is the price **agreed at booking time**. Seasonal rates change later; the bill must not. |
| `reservations` has check-in/out **and** each room has a `stay` | A room can be added for part of a stay (e.g. a second room for one night only). |
| `folio_charges.amount` is stored | Service prices change; the charge records what the guest was actually billed. |
| Room overlap prevented by an **exclusion constraint** | Normalisation removes duplicated facts, but cannot stop two rows claiming the same room for the same nights. The `no_double_booking` constraint does. |

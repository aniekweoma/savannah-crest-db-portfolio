# 01: Database Design and Modelling

## Organisation profile

| | |
|---|---|
| **Organisation** | Savannah Crest Hotels (simulated) |
| **Location** | Abuja, Nigeria |
| **Properties** | Savannah Crest Asokoro (40 rooms), Savannah Crest Jabi (60 rooms), Savannah Crest Gwarinpa (50 rooms) |
| **Business** | Hotel accommodation with on-site services: restaurant, laundry, spa and airport pickup |
| **Booking channels** | Website, phone, walk-in and online travel agents (OTAs) |

## Who uses the database

- **Reservations agents and the website:** search availability, create, change and cancel bookings.
- **Front desk officers:** check guests in and out, assign rooms.
- **Service staff (restaurant, laundry, spa, drivers):** post charges to a guest's bill (folio).
- **Accounts:** take deposits, settle bills, issue refunds.
- **Property managers:** set seasonal prices, monitor occupancy and revenue.

## What the database stores

Properties, room types, individual rooms, seasonal prices, guests, staff, reservations, the rooms and nights each reservation holds, services, charges posted to guest bills, and payments.

## What the database must support

1. Search which rooms are free for a given date range at a property.
2. Create, modify and cancel reservations, across one or more rooms.
3. **Guarantee that a room is never booked for overlapping nights.**
4. Apply the correct nightly price for the season.
5. Check guests in and out.
6. Post service charges to a guest's bill and record payments.
7. Report occupancy and revenue per property.

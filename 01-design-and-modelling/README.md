# 01: Design and Modelling

**Savannah Crest Hotels** (simulated), Abuja: 3 hotels (Asokoro 40 rooms, Jabi 60, Gwarinpa 50).
**Users:** reservations agents, front desk, service staff, accounts, managers.
**Must support:** availability search, bookings and cancellations, **no overlapping room bookings**, seasonal prices, check-in/out, guest bills, payments, occupancy reports.

## Diagram

![ER diagram](evidence/erd_rendered.png)

11 tables. `reservation_rooms` links bookings to rooms (one booking can hold several rooms). Source: [`erd.md`](erd.md).

## Key design choices ([`schema.sql`](schema.sql))

| Choice | Why |
|---|---|
| A stay is one **date range**, e.g. `[2026-12-20,2026-12-23)` | `[` includes the first night, `)` excludes checkout day, so one guest can leave the day another arrives |
| **Exclusion constraint** `no_double_booking` | Rejects two active bookings of the same room with overlapping nights (a UNIQUE rule can't detect overlaps) |
| Exclusion constraint `no_overlapping_rates` | Two price seasons can't cover the same dates |
| **Trigger** `trg_check_room_property` | A booking can't use a room from a different hotel |
| **Trigger** `trg_release_rooms` | Cancelling a booking frees its rooms automatically |
| CHECK and UNIQUE rules | Valid statuses, positive prices, check-out after check-in, unique room numbers per hotel |

Normalisation from a booking spreadsheet to BCNF, with functional dependencies: [`normalisation.md`](normalisation.md).

## Tests ([`integrity_tests.sql`](integrity_tests.sql))

12 automated tests, each marked PASS or FAIL, all rolled back afterwards. **12/12 passed**, including: overlapping booking rejected, back-to-back booking accepted, cancelled room re-bookable, room from another hotel rejected, overlapping price season rejected.

![Test report](evidence/integrity_tests.png)

## How to run

    sudo -u postgres createdb savannah_crest
    psql -U postgres -h localhost -d savannah_crest -f schema.sql
    psql -U postgres -h localhost -d savannah_crest -f integrity_tests.sql

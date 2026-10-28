# Savannah Crest Hotels: Entity-Relationship Diagram

```mermaid
erDiagram
    PROPERTIES ||--o{ ROOMS : contains
    ROOM_TYPES ||--o{ ROOMS : classifies
    PROPERTIES ||--o{ SEASONAL_RATES : sets
    ROOM_TYPES ||--o{ SEASONAL_RATES : "priced by"
    PROPERTIES ||--o{ STAFF : employs
    GUESTS ||--o{ RESERVATIONS : makes
    PROPERTIES ||--o{ RESERVATIONS : receives
    RESERVATIONS ||--|{ RESERVATION_ROOMS : holds
    ROOMS ||--o{ RESERVATION_ROOMS : "assigned in"
    RESERVATIONS ||--o{ FOLIO_CHARGES : accrues
    SERVICES ||--o{ FOLIO_CHARGES : "billed as"
    STAFF ||--o{ FOLIO_CHARGES : posts
    RESERVATIONS ||--o{ PAYMENTS : "settled by"

    PROPERTIES {
        int property_id PK
        varchar name UK
        varchar district
        varchar address
        smallint star_rating
        varchar phone
    }
    ROOM_TYPES {
        int room_type_id PK
        varchar name UK
        smallint max_occupancy
        numeric base_rate
        text description
    }
    ROOMS {
        int room_id PK
        int property_id FK
        int room_type_id FK
        varchar room_number
        smallint floor
        varchar status
    }
    SEASONAL_RATES {
        int rate_id PK
        int property_id FK
        int room_type_id FK
        varchar season_name
        daterange valid_period "no overlaps per property and room type"
        numeric nightly_rate
    }
    GUESTS {
        int guest_id PK
        varchar first_name
        varchar last_name
        varchar email UK
        varchar phone
        varchar nationality
        varchar id_type
        varchar id_number
        varchar loyalty_tier
        timestamptz created_at
    }
    STAFF {
        int staff_id PK
        int property_id FK
        varchar first_name
        varchar last_name
        varchar role
        varchar email UK
        date hired_on
    }
    RESERVATIONS {
        int reservation_id PK
        int guest_id FK
        int property_id FK
        varchar channel
        varchar status
        date check_in
        date check_out
        smallint adults
        smallint children
        timestamptz booked_at
    }
    RESERVATION_ROOMS {
        int reservation_id PK, FK
        int room_id PK, FK
        daterange stay "no overlaps per room while active"
        numeric nightly_rate
        boolean active
    }
    SERVICES {
        int service_id PK
        varchar name UK
        varchar category
        numeric unit_price
    }
    FOLIO_CHARGES {
        int charge_id PK
        int reservation_id FK
        int service_id FK
        int posted_by FK
        smallint quantity
        numeric amount
        timestamptz charged_at
    }
    PAYMENTS {
        int payment_id PK
        int reservation_id FK
        numeric amount
        varchar method
        varchar payment_type
        timestamptz paid_at
    }
```

## Reading the diagram

- `||--o{` means **one to many**: one property contains many rooms.
- `||--|{` means **one to one-or-more**: every reservation holds at least one room.
- `RESERVATION_ROOMS` resolves the **many-to-many** link between reservations and rooms (one booking can hold several rooms; one room is booked many times over its life).
- `daterange` columns store a whole period (e.g. 20 to 23 December) as **one value**, which lets PostgreSQL check for overlapping stays directly.

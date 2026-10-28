#!/usr/bin/env python3
"""Savannah Crest Hotels: synthetic data generator (Portfolio 2).
Writes CSV files to /tmp/savannah_crest_data for loading with \\copy.
IDs are assigned by PostgreSQL in file order (tables are truncated with
RESTART IDENTITY first), so row N of each file gets ID N."""
import csv
import random
from collections import Counter
from datetime import date, datetime, time, timedelta
from pathlib import Path

random.seed(2026)                       # reproducible
OUT = Path("/tmp/savannah_crest_data")
OUT.mkdir(exist_ok=True)
START, END = date(2022, 1, 1), date(2026, 12, 31)
SNAPSHOT = date(2026, 10, 28)           # "today" for statuses

# property_id: (rooms, floors, price factor)  1 Asokoro 5*, 2 Jabi 4*, 3 Gwarinpa 3*
PROPERTIES = {1: (40, 4, 1.40), 2: (60, 5, 1.15), 3: (50, 5, 1.00)}
# room_type_id: (base rate NGN, max occupancy)  1 Standard, 2 Deluxe, 3 Executive Suite, 4 Family Room
ROOM_TYPES = {1: (45000, 2), 2: (65000, 2), 3: (120000, 3), 4: (90000, 4)}
TYPE_MIX = [1] * 50 + [2] * 30 + [4] * 12 + [3] * 8
# service_id: unit price  1 Breakfast, 2 Dinner, 3 Room Service, 4 Laundry, 5 Spa, 6 Airport Pickup, 7 Minibar
SERVICES = {1: 8000, 2: 15000, 3: 6000, 4: 2500, 5: 25000, 6: 20000, 7: 5000}

NG_FIRST = ["Chinedu", "Emeka", "Tunde", "Musa", "Ibrahim", "Segun", "Yusuf", "Ikenna",
            "Obinna", "Kunle", "Uche", "Bayo", "Amaka", "Ngozi", "Fatima", "Aisha",
            "Funmilayo", "Chioma", "Zainab", "Blessing", "Adaeze", "Halima", "Yetunde",
            "Nkechi", "Folake", "Hauwa", "Ifeoma", "Tola", "Kemi", "Efe"]
NG_LAST = ["Okafor", "Adeyemi", "Bello", "Ibrahim", "Eze", "Okonkwo", "Abubakar",
           "Ogunleye", "Nwosu", "Danjuma", "Usman", "Olawale", "Chukwu", "Mohammed",
           "Adebayo", "Obi", "Lawal", "Afolabi", "Garba", "Nnamdi", "Etim", "Udo"]
FOREIGN = {
    "Ghanaian": (["Kwame", "Ama", "Kofi", "Akosua", "Yaw"], ["Mensah", "Owusu", "Boateng", "Asante"]),
    "British": (["James", "Emily", "Oliver", "Sophie"], ["Smith", "Taylor", "Brown", "Wilson"]),
    "American": (["Michael", "Ashley", "David", "Jessica"], ["Johnson", "Miller", "Davis", "Garcia"]),
    "Chinese": (["Wei", "Li", "Ming", "Xin"], ["Wang", "Zhang", "Chen", "Liu"]),
    "South African": (["Thabo", "Naledi", "Pieter", "Lerato"], ["Nkosi", "Botha", "Dlamini", "Naidoo"]),
}
NATIONALITIES = ["Nigerian"] * 82 + ["Ghanaian"] * 5 + ["British"] * 4 + ["American"] * 3 \
                + ["Chinese"] * 3 + ["South African"] * 3
N_GUESTS = 15000


def ts(d, h=None, m=None):
    """Timestamp string in West Africa Time."""
    h = random.randint(7, 22) if h is None else h
    m = random.randint(0, 59) if m is None else m
    return f"{datetime.combine(d, time(h, m)):%Y-%m-%d %H:%M:%S}+01"


def write(name, rows):
    with open(OUT / f"{name}.csv", "w", newline="") as f:
        csv.writer(f).writerows(rows)
    print(f"{name:20s} {len(rows):>8,} rows")


# ---------- Seasons (contiguous, never overlapping) ----------
SEASONS = [("Festive 2021/22", date(2022, 1, 1), date(2022, 1, 10), 1.35)]
for y in range(2022, 2027):
    SEASONS += [(f"Low {y}", date(y, 1, 10), date(y, 4, 1), 0.85),
                (f"Standard {y}", date(y, 4, 1), date(y, 10, 1), 1.00),
                (f"Conference {y}", date(y, 10, 1), date(y, 12, 15), 1.15),
                (f"Festive {y}/{str(y + 1)[2:]}", date(y, 12, 15), date(y + 1, 1, 10), 1.35)]


def rate_for(pid, t, d):
    for _, s, e, mult in SEASONS:
        if s <= d < e:
            return round(ROOM_TYPES[t][0] * PROPERTIES[pid][2] * mult, -2)
    raise ValueError(d)


seasonal = [(pid, t, name, f"[{s},{e})", round(ROOM_TYPES[t][0] * PROPERTIES[pid][2] * mult, -2))
            for pid in PROPERTIES for t in ROOM_TYPES for name, s, e, mult in SEASONS]

# ---------- Rooms ----------
rooms, room_meta = [], []
for pid, (n, floors, _) in PROPERTIES.items():
    per_floor = n // floors
    for i in range(n):
        floor = i // per_floor + 1
        t = random.choice(TYPE_MIX)
        status = "Maintenance" if random.random() < 0.02 else "Available"
        rooms.append((pid, t, f"{floor}{i % per_floor + 1:02d}", floor, status))
        room_meta.append((len(rooms), pid, t))

# ---------- Staff ----------
ROLES = [("Front Desk", 6), ("Reservations", 3), ("Housekeeping", 8),
         ("Service", 6), ("Accounts", 2), ("Manager", 1)]
staff, service_staff = [], {1: [], 2: [], 3: []}
for pid in PROPERTIES:
    for role, count in ROLES:
        for _ in range(count):
            fn, ln = random.choice(NG_FIRST), random.choice(NG_LAST)
            sid = len(staff) + 1
            staff.append((pid, fn, ln, role, f"{fn}.{ln}.{sid}@savannahcrest.ng".lower(),
                          START - timedelta(days=random.randint(0, 2500))))
            if role == "Service":
                service_staff[pid].append(sid)

# ---------- Reservations, room stays, charges, payments ----------
reservations, res_rooms, folio, payments = [], [], [], []
stays = Counter()
for room_id, pid, t in room_meta:
    d = START + timedelta(days=random.randint(0, 3))
    while d < END:
        nights = random.choices([1, 2, 3, 4, 5, 7], [25, 25, 20, 12, 10, 8])[0]
        ci, co = d, d + timedelta(days=nights)
        channel = random.choices(["Website", "Phone", "Walk-in", "OTA"], [40, 20, 15, 25])[0]
        guest = random.randint(1, 1500) if random.random() < 0.3 else random.randint(1, N_GUESTS)
        occ = ROOM_TYPES[t][1]
        adults = min(random.choice([1, 1, 2, 2, 2, 3]), occ)
        children = random.randint(0, 2) if t == 4 else 0
        booked_day = ci if channel == "Walk-in" else ci - timedelta(days=random.randint(1, 60))
        booked_at = ts(booked_day)

        r = random.random()
        if ci > SNAPSHOT:
            status = "Cancelled" if r < 0.07 else "Confirmed"
        elif co <= SNAPSHOT:
            status = "Cancelled" if r < 0.07 else ("No-show" if r < 0.11 else "Checked-out")
        else:
            status = "Cancelled" if r < 0.05 else "Checked-in"
        if channel == "Walk-in" and status in ("Cancelled", "No-show"):
            status = "Checked-out" if co <= SNAPSHOT else ("Checked-in" if ci <= SNAPSHOT else "Confirmed")

        reservations.append((guest, pid, channel, status, ci, co, adults, children, booked_at))
        res_id = len(reservations)

        rate = rate_for(pid, t, ci)
        if channel == "OTA":
            rate = round(rate * 0.95, -2)
        active = "f" if status in ("Cancelled", "No-show") else "t"
        res_rooms.append((res_id, room_id, f"[{ci},{co})", rate, active))
        room_total = rate * nights

        extras = 0
        if status in ("Checked-out", "Checked-in"):
            stays[guest] += 1
            if random.random() < 0.2:
                folio.append((res_id, 6, random.choice(service_staff[pid]), 1, 20000, ts(ci, 14)))
                extras += 20000
            for k in range(nights):
                night = ci + timedelta(days=k)
                if night > SNAPSHOT:
                    break
                for _ in range(random.randint(0, 2)):
                    sid = random.choices([1, 2, 3, 4, 5, 7], [30, 20, 15, 15, 5, 15])[0]
                    qty = random.randint(1, 3) if sid in (1, 2, 4) else 1
                    amount = SERVICES[sid] * qty
                    folio.append((res_id, sid, random.choice(service_staff[pid]), qty, amount, ts(night)))
                    extras += amount

        deposit = 0
        if channel in ("Website", "OTA"):
            deposit = round(room_total * 0.3, -2)
            payments.append((res_id, deposit, "Card" if channel == "Website" else "Transfer",
                             "Deposit", booked_at))
        if status == "Checked-out":
            balance = room_total + extras - deposit
            if balance > 0:
                payments.append((res_id, balance, random.choice(["Card", "Transfer", "Cash", "POS"]),
                                 "Balance", ts(co, 11, random.randint(0, 59))))
        if status == "Cancelled" and deposit > 0:
            payments.append((res_id, deposit, "Transfer", "Refund", ts(booked_day + timedelta(days=1))))

        d = co + timedelta(days=random.choices([0, 1, 2, 3, 5, 8], [30, 25, 15, 12, 10, 8])[0])

# ---------- Guests (loyalty tier from completed stays) ----------
guests = []
for gid in range(1, N_GUESTS + 1):
    nat = random.choice(NATIONALITIES)
    if nat == "Nigerian":
        fn, ln = random.choice(NG_FIRST), random.choice(NG_LAST)
        id_type = random.choices(["NIN", "Driver Licence", "Voter Card"], [60, 25, 15])[0]
        id_no = str(random.randint(10**10, 10**11 - 1))
    else:
        fn, ln = random.choice(FOREIGN[nat][0]), random.choice(FOREIGN[nat][1])
        id_type, id_no = "Passport", f"P{random.randint(10**7, 10**8 - 1)}"
    email = f"{fn}.{ln}.{gid}@example.com".lower() if random.random() < 0.75 else ""
    n = stays[gid]
    tier = "Platinum" if n >= 15 else "Gold" if n >= 8 else "Silver" if n >= 4 else "None"
    guests.append((fn, ln, email, f"080{gid:08d}", nat, id_type, id_no, tier,
                   ts(START - timedelta(days=random.randint(0, 365)))))

write("rooms", rooms)
write("seasonal_rates", seasonal)
write("guests", guests)
write("staff", staff)
write("reservations", reservations)
write("reservation_rooms", res_rooms)
write("folio_charges", folio)
write("payments", payments)

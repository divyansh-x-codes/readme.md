# Phase 1: Problem Understanding & Requirements Analysis
**Project:** BookMyShow Movie & Event Ticketing Database (DBMS Project 2026)  
**Team:** T0052 · **Section:** A · **Database:** PostgreSQL 16+  
**Scope:** Phase 1 Deliverable (`docs/01_problem_understanding.md`)

---

## 1. Project Title & Objective

### Title
**High-Throughput Relational Database Architecture for BookMyShow Ticket Reservation and Box-Office Analytics**

### Objective
The core objective of this project is to reconstruct, formally constrain, validate, and optimize the operational relational database schema for a nationwide movie ticketing platform (BookMyShow) covering the April–July 2026 theatrical window. The database must faithfully preserve atomic seat reservation invariants, enforce complex business constraints, guarantee referential integrity across 11 core entities, and sustain both real-time customer booking transactions and heavy analytical box-office workloads across multi-screen cinema networks.

---

## 2. Business Problem & Context

BookMyShow operates as an online ticketing intermediary between movie-goers and cinema chains (such as PVR, INOX, Cinepolis, and independent theatres). The business is characterized by:
1. **Hierarchical Physical Infrastructure:** Cities contain cinema **Venues**, each venue houses multiple auditoriums (**Screens**), and each screen has a fixed spatial **Seat layout** classified into pricing tiers (`CLASSIC`, `PRIME`, `RECLINER`).
2. **Temporal Scheduling:** A **Show** represents the screening of a specific **Movie** on a specific **Screen** at a scheduled start and end time. Two shows can never overlap in time on the same auditorium screen.
3. **Seat-by-Seat Reservation Invariant:** Seats are reserved and sold individually. A physical seat inside a screen can be sold **at most once per show**.
4. **Checkout Lifecycle:** A customer initiates a booking, placing selected seats into a temporary hold state (`PENDING`). If payment succeeds, the status transitions to `CONFIRMED`; if the customer abandons the transaction or the session times out (typically after 10 minutes), the hold expires, and the seats must be released for other buyers.
5. **Multi-Item Financial Composition:** A booking total comprises ticket prices, convenience fees, optional Food & Beverage (F&B) purchases, minus promotional discount vouchers (`Offers`).

The previous system suffered from an undocumented schema, unconstrained data tables, and severe query performance degradation during high-traffic release windows.

---

## 3. Analysis of Reported Problems (P1 – P8)

The table below analyzes each reported problem, identifying the core business need, the impacted stakeholder, the architectural workload classification, the corresponding queries from `workload_30.sql`, and the SLA performance target for large-scale operations.

| Problem ID | Problem Description | Business Need & Impact | Impacted Stakeholder | Workload Classification | Related Queries | SLA Target (Large Data) |
|---|---|---|---|---|---|:---:|
| **P1** | *"Now showing, showtimes and search pages are slow on Friday mornings."* | Friday morning ticket rushes cause heavy read contention on catalog browsing. The business needs instantaneous catalog lookup by city, date, and movie format without table scans. | Movie-goers, Customer Experience | **Customer-Facing / Real-Time** | `R01`, `R02`, `R06` | `< 5 ms` / `< 250 ms` |
| **P2** | *"The seat layout screen and seat locking are too slow, and two people must never get the same seat."* | Real-time seat grid rendering and atomic seat reservation. Prevent double-booking race conditions while displaying unsold seats rapidly. | Movie-goers, Booking Engine Service | **Customer-Facing / Real-Time** (OLTP) | `R03`, `W01`, `W02` | `< 5 ms` |
| **P3** | *"Payments: the pending-payment queue, confirmations and seat-lock expiry jobs lag."* | High-concurrency transaction processing. Automated background workers must identify and expire stale reservations (>10 min) while payment webhooks confirm successful orders instantly. | Payments Team, Inventory / Lock Service | **Customer-Facing / Real-Time** (OLTP) | `R09`, `W03`, `W04` | `< 5 ms` (Locks), `< 250 ms` (Expiry) |
| **P4** | *"Customers and support wait too long for My bookings, booking lookup and sign-in."* | Customer profile access, historical order retrieval, support ticket resolution, and mobile-number authentication require single-digit millisecond response times. | Support Agents, Movie-goers | **Customer-Facing / Real-Time** | `R04`, `R05`, `R22`, `R23` | `< 5 ms` (Lookup), `< 250 ms` (Console) |
| **P5** | *"Cinema managers need occupancy, cleaning-gap checks and never-sold seats per screen."* | Daily cinema operations require monitoring show-level occupancy rates, identifying turnaround cleaning gaps (<30 min) between back-to-back shows, and locating structurally dead seats. | Cinema / Venue Operations Managers | **Reporting / Analytics** | `R07`, `R10`, `R17`, `R25` | `< 250 ms` / `< 5,000 ms` |
| **P6** | *"Partnerships' 'offers never redeemed' report is always empty."* | Marketing partnerships team needs to identify ineffective coupon codes. The current SQL query fails due to anti-pattern `NOT IN (SELECT offer_code FROM bookings)` with NULL values, requiring correction. | Marketing & Partnerships Team | **Reporting / Analytics** | `R13` | `< 250 ms` |
| **P7** | *"Distributors want box-office and per-show ticket counts during release weekends."* | Content distributors and production houses demand real-time revenue collection figures and per-show attendance reports over opening release weekends to determine print allocations. | Film Distributors, Studio Partners | **Reporting / Analytics** | `R08`, `R19`, `W05` | `< 5,000 ms` (Reports), `< 250 ms` (Repricing) |
| **P8** | *"Finance and insight reports time out, and volume will grow 20×."* | Executive and finance teams require aggregate financial settlement, regional linguistic preferences, loyalty trends, and daily running totals without degrading operational transaction throughput. | Finance Team, Executive Leadership, BI Analysts | **Reporting / Analytics** (OLAP) | `R11`, `R12`, `R14`, `R15`, `R16`, `R18`, `R20`, `R21`, `R24` | `< 5,000 ms` |

---

## 4. Major Entities & System Requirements

The database captures 11 core entities across the ticketing lifecycle:

```
[cities] ──< [venues] ──< [screens] ──< [seats] ──< [booking_seats]
               │                      ▲                     │
               │                      │                     │
               └──< [shows] ──────────┘                     │
                      ▲                                     │
                      │                                     ▼
[movies] ─────────────┴───────────────────────────────> [bookings] ──> [offers]
   ▲                                                        ▲
   │                                                        │
   └──────────────< [movie_reviews] >───────────────────────┴── [customers]
```

### 4.1 Functional Requirements Supported by Seed Data
1. **Auditorium Seat Topology:** Store distinct seat layouts for each screen, supporting rows, seat numbers, and pricing tiers (`CLASSIC`, `PRIME`, `RECLINER`).
2. **Scheduling Engine:** Schedule film screenings with explicit start and end times, format specifications (`2D`, `3D`, `4DX`, `IMAX`), and base ticket pricing.
3. **Reservation & Cart Management:** Facilitate multi-ticket checkouts linking a customer, show, selected seats, optional promotion codes, and payment methods.
4. **Financial Reconciliation:** Guarantee that every booking satisfies the equation:
   $$\text{total\_amount} = \text{ticket\_amount} + \text{convenience\_fee} + \text{fnb\_amount} - \text{discount}$$
5. **Audience Sentiment:** Record customer reviews with numerical ratings (1–10) and optional qualitative feedback, constrained to at most one review per customer per film.

---

## 5. Database Integrity Requirements

1. **Entity Integrity:** Every physical entity must have an immutable, unique primary key (`city_id`, `venue_id`, `screen_id`, `seat_id`, `movie_id`, `show_id`, `customer_id`, `offer_code`, `booking_id`, `review_id`).
2. **Associative Uniqueness (The No-Double-Booking Rule):** In `booking_seats`, the composite pair `(show_id, seat_id)` must be strictly `UNIQUE`. This physical constraint at the database layer makes it impossible for concurrent transactions to allocate the same physical seat for the same show.
3. **Temporal Non-Overlap Constraint:** Two shows scheduled on the same screen must never overlap in time. This is formally enforced via a PostgreSQL exclusion constraint:
   `EXCLUDE USING gist (screen_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)`
4. **Referential Integrity & Delete Policies:**
   - Deleting a cinema venue or screen cascades to its child screens and seats (`ON DELETE CASCADE`), reflecting physical decommissioning.
   - Deleting a movie, show, customer, or city is restricted (`ON DELETE RESTRICT`) whenever active operational or transactional records depend on it.
   - Deleting or retiring a promotional voucher sets the booking reference to NULL (`ON DELETE SET NULL`), preserving transaction history.
5. **Domain Integrity:** Strict `CHECK` constraints on enumeration fields (`screen_type`, `seat_class`, `format`, `payment_method`, `status`, `certificate`), positive monetary amounts, and regex formatting on `email`, `phone`, and `booking_code`.

---

## 6. Assumptions & Limitations

1. **Data Scope:** The supplied seed data covers theatrical screenings and bookings between April 1, 2026, and July 7, 2026.
2. **Pricing Structure:** Ticket pricing in `booking_seats` is derived from the show base price adjusted by seat class (e.g., recliner multiplier).
3. **Seat Reservation Lifecycle:** While live production systems utilize Redis locks for transient seconds-level checkout holding, the DBMS architecture represents seat reservation states directly within `bookings.status` (`PENDING`, `CONFIRMED`, `CANCELLED`, `PAYMENT_FAILED`) and `booking_seats`.
4. **Out of Scope for Phase 1 & 2:**
   - Real-world external payment gateway integrations (Razorpay, Stripe) and HTTP webhooks.
   - User authentication infrastructure (OAuth, bcrypt password hashing, JWT tokens).
   - Dynamic pricing machine-learning models.
   - Query performance index tuning (reserved strictly for Phase 4).

---

## 7. Why Relational Database Design (PostgreSQL) is Appropriate

1. **ACID Guarantees:** Ticket inventory reservation is a zero-sum, high-contention problem. PostgreSQL provides strict Serializability/Read Committed isolation levels, preventing overselling and phantom bookings.
2. **Declarative Relational Constraints:** Foreign keys, composite unique constraints, and exclusion constraints guarantee that invalid states cannot enter the storage layer regardless of application bug vectors.
3. **Expressive Querying:** PostgreSQL easily joins deep hierarchies (City $\rightarrow$ Venue $\rightarrow$ Screen $\rightarrow$ Show $\rightarrow$ Booking $\rightarrow$ Seats) for real-time reporting and analytical box-office window functions.

---

## 8. Phase Scope Boundary Statement

- **Phases 1 & 2 (Current Scope):** Focus solely on business problem analysis, schema specification, constraint modeling, data dictionary authoring, ER modeling, seed data ingestion, and integrity validation. **No performance tuning indexes are created in this phase.**
- **Phases 3, 4 & 5 (Subsequent Scopes):** Phase 3 measures raw baseline execution times across all 30 queries on this unindexed schema. Phase 4 introduces indexes and sargable query refactoring. Phase 5 evaluates 20× dataset scalability and architectural partitioning.

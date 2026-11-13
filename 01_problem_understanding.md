# Phase 1: Problem Understanding

**Project:** BookMyShow Movie & Event Ticketing Database (DBMS Project 2026)  
**Team:** T0052 · **Section:** A · **Database:** PostgreSQL 15 or newer  
**File:** `docs/01_problem_understanding.md`

---

## 1. Project Overview & Objective

BookMyShow operates an online movie ticket reservation platform that sells cinema tickets **seat by seat**. The physical hierarchy spans **Cities** containing multiplex **Venues**, each housing multiple **Screens** with dedicated physical **Seat layouts** (Classic, Prime, Recliner). A **Show** represents a movie screening on a specific screen at a scheduled time, and two shows can never overlap on the same screen. When a customer initiates a booking, seats are temporarily locked during payment; a seat can be sold **only once per show**. 

The current database covers shows and transactions from April to early July 2026. Because it was set up without a documented schema or proper constraints, various product and operational teams report severe usability, data accuracy, and query execution issues. The objective of Phase 1 is to analyze these reported problems, define the business needs, identify affected stakeholders, and classify each workload to establish clear foundations for schema design and query optimization.

---

## 2. Problem Statements Analysis (P1 – P8)

| Problem ID | Problem Description | Business Need & Impact | Impacted Stakeholder | Workload Classification | Related Queries |
|---|---|---|---|---|:---:|
| **P1** | *"Now showing, showtimes and search pages are slow on Friday mornings."* | Friday morning ticket rushes cause heavy catalog browsing traffic. The platform must provide immediate movie search, showtime listings by city, and schedule lookups so movie-goers do not abandon ticket purchases during peak opening windows. | Movie-goer | **Customer-Facing / Real-Time** | R01, R02, R06 |
| **P2** | *"The seat layout screen and seat locking are too slow, and two people must never get the same seat."* | Real-time seat grid rendering and atomic seat reservation. The booking engine must quickly display seat availability by class and strictly guarantee that concurrent buyers cannot reserve or purchase the same seat for the same show. | Movie-goer, Booking engine | **Customer-Facing / Real-Time** | R03, W01, W02 |
| **P3** | *"Payments: the pending-payment queue, confirmations and seat-lock expiry jobs lag."* | High-concurrency checkout lifecycle management. System background jobs must promptly identify and release expired pending seat holds (>10 minutes) back to inventory, while payment confirmation callbacks must update booking statuses without delay. | Payments / seat-lock service, Movie-goer | **Customer-Facing / Real-Time** | R09, W03, W04 |
| **P4** | *"Customers and support wait too long for My bookings, booking lookup and sign-in."* | Fast customer profile retrieval, booking lookup by confirmation code, customer sign-in via phone number, and efficient paginated booking listings for customer support representatives resolving customer inquiries. | Support, Movie-goer | **Customer-Facing / Real-Time** | R04, R05, R22, R23 |
| **P5** | *"Cinema managers need occupancy, cleaning-gap checks and never-sold seats per screen."* | Daily venue operations management. Cinema staff require operational reports to monitor show occupancy, detect back-to-back shows with less than 30 minutes of cleaning turnaround time, and identify structurally unsold seats on specific screens for maintenance or re-tiering. | Cinema / venue manager, Programming team | **Reporting / Analytics** | R07, R10, R17, R25 |
| **P6** | *"Partnerships' 'offers never redeemed' report is always empty."* | Marketing partnership evaluation. The partnerships team needs an accurate list of promo voucher codes that have never been used to assess commercial campaigns, clean up inactive partnerships, and fix query logic issues caused by NULL values in subqueries. | Partnerships | **Reporting / Analytics** | R13 |
| **P7** | *"Distributors want box-office and per-show ticket counts during release weekends."* | Film box-office auditing. Studio partners and distributors require accurate weekend box-office collections, per-show ticket tallies, and prompt schedule pricing updates across cinemas to verify revenue splits and theater print allocations. | Distributor | **Reporting / Analytics** | R08, R19, W05 |
| **P8** | *"Finance and insight reports (revenue mix, regional collections, ratings, loyalty, booking patterns, cancellations) time out, and volume will grow 20×."* | Long-range financial planning and business intelligence. Management requires multi-table aggregations covering seat-class revenue mix, city-wise language collections, top customer loyalty, cancellation rates, and daily revenue running totals across large historical datasets without system timeouts. | Finance | **Reporting / Analytics** | R11, R12, R14, R15, R16, R18, R20, R21, R24 |

---

## 3. Workload Classification Summary

The 30 workload queries fall into two operational categories:

1. **Customer-Facing / Real-Time Workloads (`P1`–`P4`):**
   - **Characteristics:** High-concurrency, latency-critical online transactional processing (OLTP). These queries directly power end-user interactions on web/mobile apps and live operational services (search, seat grid, payment locks, sign-in, order lookup).
   - **Related Queries:** `R01`, `R02`, `R03`, `R04`, `R05`, `R06`, `R09`, `R22`, `R23`, `W01`, `W02`, `W03`, `W04`.

2. **Reporting / Analytics Workloads (`P5`–`P8`):**
   - **Characteristics:** Complex, multi-table join and aggregation queries (OLAP) covering large date ranges and historical transactions. These queries serve internal business stakeholders (cinema managers, film distributors, marketing partnerships, and finance).
   - **Related Queries:** `R07`, `R08`, `R10`, `R11`, `R12`, `R13`, `R14`, `R15`, `R16`, `R17`, `R18`, `R19`, `R20`, `R21`, `R24`, `R25`, `W05`.

---

## 4. Key Assumptions

1. **Data Timeline:** The operational dataset reflects theatrical screenings, venues, customers, and bookings spanning April 1, 2026 through July 7, 2026.
2. **Single-Sale Invariant:** A specific physical seat within an auditorium screen can be reserved or sold at most once for any given show (`UNIQUE (show_id, seat_id)`).
3. **Temporal Non-Overlap:** Each auditorium screen can host only one show at any point in time; screenings on the same screen cannot have overlapping time intervals.
4. **Checkout Lifecycle:** Seats associated with a `PENDING` booking are temporarily reserved. If the booking status becomes `CANCELLED` or `PAYMENT_FAILED`, the seats are released and no longer belong to an active reservation.
5. **Scope Separation:** Phase 1 defines the operational requirements and problem scope. Schema creation and data ingestion take place in Phase 2; query execution measurement (baseline) and index tuning take place in Phases 3 and 4 respectively.


-- Step 1: Extension required for the non-overlapping show exclusion constraint
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Step 2: Create and set the project schema
CREATE SCHEMA IF NOT EXISTS bms;
SET search_path TO bms;


-- 1. CITIES
-- Stores the operational cities where cinemas and customers are located.

CREATE TABLE cities (
    city_id     INT PRIMARY KEY,
    city_name   VARCHAR(50) NOT NULL UNIQUE,
    state       VARCHAR(50) NOT NULL
);


-- 2. VENUES
-- Stores cinema theatres and multiplexes located in each city.

CREATE TABLE venues (
    venue_id    INT PRIMARY KEY,
    venue_name  VARCHAR(100) NOT NULL UNIQUE,
    city_id     INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    chain       VARCHAR(50) NOT NULL CHECK (chain IN ('Cinepolis', 'INOX', 'Independent', 'Miraj', 'PVR')),
    address     TEXT NOT NULL
);


-- 3. SCREENS
-- Stores individual auditoriums inside each cinema venue.
CREATE TABLE screens (
    screen_id   INT PRIMARY KEY,
    venue_id    INT NOT NULL REFERENCES venues(venue_id) ON DELETE CASCADE,
    screen_name VARCHAR(50) NOT NULL,
    screen_type VARCHAR(20) NOT NULL CHECK (screen_type IN ('4DX', 'GOLD', 'IMAX', 'STANDARD')),
    total_seats INT NOT NULL CHECK (total_seats > 0),
    CONSTRAINT uq_screens_venue_screen UNIQUE (venue_id, screen_name)
);


-- 4. SEATS
-- Stores the physical seat layout for each screen (row, number, class).
CREATE TABLE seats (
    seat_id     INT PRIMARY KEY,
    screen_id   INT NOT NULL REFERENCES screens(screen_id) ON DELETE CASCADE,
    row_label   VARCHAR(5) NOT NULL,
    seat_number INT NOT NULL CHECK (seat_number > 0),
    seat_class  VARCHAR(20) NOT NULL CHECK (seat_class IN ('CLASSIC', 'PRIME', 'RECLINER')),
    CONSTRAINT uq_seats_screen_row_number UNIQUE (screen_id, row_label, seat_number)
);


-- 5. MOVIES
-- Catalog of movies available for screening.
CREATE TABLE movies (
    movie_id     INT PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    language     VARCHAR(50) NOT NULL CHECK (language IN ('Bengali', 'English', 'Hindi', 'Kannada', 'Malayalam', 'Marathi', 'Tamil', 'Telugu')),
    certificate  VARCHAR(10) NOT NULL CHECK (certificate IN ('A', 'U', 'UA')),
    duration_min INT NOT NULL CHECK (duration_min > 0),
    release_date DATE NOT NULL
);


-- 6. SHOWS
-- Schedules a movie screening on a specific screen at a given time.
-- Enforces that two shows on the same screen cannot overlap in time.

CREATE TABLE shows (
    show_id     INT PRIMARY KEY,
    movie_id    INT NOT NULL REFERENCES movies(movie_id) ON DELETE RESTRICT,
    screen_id   INT NOT NULL REFERENCES screens(screen_id) ON DELETE RESTRICT,
    starts_at   TIMESTAMPTZ NOT NULL,
    ends_at     TIMESTAMPTZ NOT NULL,
    format      VARCHAR(10) NOT NULL CHECK (format IN ('2D', '3D', '4DX', 'IMAX')),
    base_price  NUMERIC(8, 2) NOT NULL CHECK (base_price > 0),
    CONSTRAINT chk_shows_time_order CHECK (ends_at > starts_at),
    CONSTRAINT ex_shows_no_overlap EXCLUDE USING gist (
        screen_id WITH =,
        tstzrange(starts_at, ends_at, '[)') WITH &&
    )
);


-- 7. CUSTOMERS
-- Registered users who book tickets and post reviews.
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    phone       VARCHAR(15) NOT NULL UNIQUE,
    city_id     INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    created_at  TIMESTAMPTZ NOT NULL
);


-- 8. OFFERS
-- Promotional discount offers and vouchers.
CREATE TABLE offers (
    offer_code   VARCHAR(20) PRIMARY KEY,
    description  VARCHAR(100) NOT NULL,
    discount_pct INT NOT NULL CHECK (discount_pct > 0 AND discount_pct <= 100),
    max_discount NUMERIC(8, 2) NOT NULL CHECK (max_discount > 0),
    valid_from   DATE NOT NULL,
    valid_to     DATE NOT NULL,
    CONSTRAINT chk_offers_validity CHECK (valid_to >= valid_from)
);


-- 9. BOOKINGS
-- Customer transactions for ticket reservations.
-- Enforces calculation: total_amount = ticket + fee + fnb - discount.
CREATE TABLE bookings (
    booking_id      INT PRIMARY KEY,
    booking_code    VARCHAR(12) NOT NULL UNIQUE,
    customer_id     INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    show_id         INT NOT NULL REFERENCES shows(show_id) ON DELETE RESTRICT,
    booked_at       TIMESTAMPTZ NOT NULL,
    num_tickets     INT NOT NULL CHECK (num_tickets > 0),
    ticket_amount   NUMERIC(8, 2) NOT NULL CHECK (ticket_amount >= 0),
    convenience_fee NUMERIC(8, 2) NOT NULL CHECK (convenience_fee >= 0),
    fnb_amount      NUMERIC(8, 2) NOT NULL DEFAULT 0.00 CHECK (fnb_amount >= 0),
    offer_code      VARCHAR(20) NULL REFERENCES offers(offer_code) ON DELETE SET NULL,
    discount        NUMERIC(8, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    total_amount    NUMERIC(8, 2) NOT NULL CHECK (total_amount >= 0),
    payment_method  VARCHAR(20) NOT NULL CHECK (payment_method IN ('CARD', 'GIFT_CARD', 'NETBANKING', 'UPI', 'WALLET')),
    status          VARCHAR(20) NOT NULL CHECK (status IN ('CANCELLED', 'CONFIRMED', 'PAYMENT_FAILED', 'PENDING')),
    CONSTRAINT chk_bookings_total_amount CHECK (
        total_amount = (ticket_amount + convenience_fee + fnb_amount - discount)
    )
);


-- 10. BOOKING_SEATS
-- Associative table linking each booking to the reserved physical seats.
-- Enforces that a seat can only be sold once per show.
CREATE TABLE booking_seats (
    booking_id INT NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
    show_id    INT NOT NULL REFERENCES shows(show_id) ON DELETE RESTRICT,
    seat_id    INT NOT NULL REFERENCES seats(seat_id) ON DELETE RESTRICT,
    price      NUMERIC(8, 2) NOT NULL CHECK (price > 0),
    PRIMARY KEY (booking_id, seat_id),
    CONSTRAINT uq_booking_seats_show_seat UNIQUE (show_id, seat_id)
);


-- 11. MOVIE_REVIEWS
-- User ratings and optional written reviews for movies.
-- Each customer can review a given movie at most once.
CREATE TABLE movie_reviews (
    review_id   INT PRIMARY KEY,
    movie_id    INT NOT NULL REFERENCES movies(movie_id) ON DELETE CASCADE,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    rating      INT NOT NULL CHECK (rating >= 1 AND rating <= 10),
    review_text TEXT NULL,
    created_at  TIMESTAMPTZ NOT NULL,
    CONSTRAINT uq_movie_reviews_movie_customer UNIQUE (movie_id, customer_id)
);

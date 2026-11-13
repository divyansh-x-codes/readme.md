
SET search_path TO bms;

-- 1. Cities (independent lookup table, 10 rows)
\echo 'Loading cities.csv...'
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);

-- 2. Venues (references cities, 140 rows)
\echo 'Loading venues.csv...'
\copy venues FROM 'seed_data/venues.csv' WITH (FORMAT csv, HEADER true);

-- 3. Screens (references venues, 490 rows)
\echo 'Loading screens.csv...'
\copy screens FROM 'seed_data/screens.csv' WITH (FORMAT csv, HEADER true);

-- 4. Seats (references screens, 94,056 rows)
\echo 'Loading seats.csv...'
\copy seats FROM 'seed_data/seats.csv' WITH (FORMAT csv, HEADER true);

-- 5. Movies (independent catalog, 300 rows)
\echo 'Loading movies.csv...'
\copy movies FROM 'seed_data/movies.csv' WITH (FORMAT csv, HEADER true);

-- 6. Shows (references movies and screens, 160,034 rows)
\echo 'Loading shows.csv...'
\copy shows FROM 'seed_data/shows.csv' WITH (FORMAT csv, HEADER true);

-- 7. Customers (references cities, 40,000 rows)
\echo 'Loading customers.csv...'
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true);

-- 8. Offers (independent discount catalog, 25 rows)
\echo 'Loading offers.csv...'
\copy offers FROM 'seed_data/offers.csv' WITH (FORMAT csv, HEADER true);

-- 9. Bookings (references customers, shows, offers, 150,094 rows)
\echo 'Loading bookings.csv...'
\copy bookings FROM 'seed_data/bookings.csv' WITH (FORMAT csv, HEADER true);

-- 10. Booking Seats (references bookings, shows, seats, 300,389 rows)
\echo 'Loading booking_seats.csv...'
\copy booking_seats FROM 'seed_data/booking_seats.csv' WITH (FORMAT csv, HEADER true);

-- 11. Movie Reviews (references movies and customers, 32,510 rows)
\echo 'Loading movie_reviews.csv...'
\copy movie_reviews FROM 'seed_data/movie_reviews.csv' WITH (FORMAT csv, HEADER true);

-- Update PostgreSQL query planner statistics
\echo 'Running ANALYZE...'
ANALYZE;

\echo 'Data load complete. Verifying row counts...'

SELECT 'cities' AS table_name, count(*) AS row_count, 10 AS expected FROM cities
UNION ALL
SELECT 'venues', count(*), 140 FROM venues
UNION ALL
SELECT 'screens', count(*), 490 FROM screens
UNION ALL
SELECT 'seats', count(*), 94056 FROM seats
UNION ALL
SELECT 'movies', count(*), 300 FROM movies
UNION ALL
SELECT 'shows', count(*), 160034 FROM shows
UNION ALL
SELECT 'customers', count(*), 40000 FROM customers
UNION ALL
SELECT 'offers', count(*), 25 FROM offers
UNION ALL
SELECT 'bookings', count(*), 150094 FROM bookings
UNION ALL
SELECT 'booking_seats', count(*), 300389 FROM booking_seats
UNION ALL
SELECT 'movie_reviews', count(*), 32510 FROM movie_reviews

ORDER BY table_name;

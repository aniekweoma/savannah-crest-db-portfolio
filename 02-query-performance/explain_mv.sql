\echo '=== H5 (after): Monthly occupancy from the materialised view ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT property_id, month, nights_sold, occupancy_pct
FROM mv_monthly_occupancy
WHERE month >= DATE '2025-01-01' AND month < DATE '2026-01-01';

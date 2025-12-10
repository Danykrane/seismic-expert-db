-- View: top10_nitrate_locations
-- Description: Top 10 locations (ports with their aquatory) by average nitrate level.
CREATE OR REPLACE VIEW top10_nitrate_locations AS
SELECT p.name AS port, aq.name AS aquatory, AVG(m.value) AS avg_nitrate
FROM measurements m
JOIN indicators ind ON ind.id = m.indicator_id
JOIN voyages v ON v.id = m.voyage_id
JOIN routes r ON r.id = v.route_id
JOIN ports p ON p.id = r.dest_port_id
JOIN aquatories aq ON aq.id = p.aquatory_id
WHERE ind.name = 'Nitrate'
GROUP BY p.name, aq.name
ORDER BY AVG(m.value) DESC
LIMIT 10;

-- View: expedition_report
-- Description: Summary report for each completed voyage (expedition).
CREATE OR REPLACE VIEW expedition_report AS
SELECT 
    v.id AS voyage_id,
    s.name AS ship,
    r.name AS route,
    v.actual_departure_date,
    v.actual_arrival_date,
    (v.actual_arrival_date - v.actual_departure_date) AS duration,
    COALESCE(COUNT(m.id), 0) AS total_measurements,
    COUNT(DISTINCT m.indicator_id) AS distinct_parameters
FROM voyages v
JOIN ships s ON s.id = v.ship_id
JOIN routes r ON r.id = v.route_id
LEFT JOIN measurements m ON m.voyage_id = v.id
WHERE v.status = 'COMPLETED'
GROUP BY v.id, s.name, r.name, v.actual_departure_date, v.actual_arrival_date;

-- View: avg_param_values_by_month
-- Description: Average values of each parameter by year and month.
CREATE OR REPLACE VIEW avg_param_values_by_month AS
SELECT 
    ind.name AS indicator,
    EXTRACT(YEAR FROM m.measured_at)::INT AS year,
    EXTRACT(MONTH FROM m.measured_at)::INT AS month,
    ROUND(AVG(m.value)::numeric, 3) AS avg_value
FROM measurements m
JOIN indicators ind ON ind.id = m.indicator_id
GROUP BY ind.name, EXTRACT(YEAR FROM m.measured_at), EXTRACT(MONTH FROM m.measured_at)
ORDER BY ind.name, year, month;

-- View: ship_report
-- Description: Summary report per ship - number of voyages, total measurements, and last completed voyage date.
CREATE OR REPLACE VIEW ship_report AS
SELECT 
    s.name AS ship,
    -- total voyages (all statuses)
    (SELECT COUNT(*) FROM voyages v WHERE v.ship_id = s.id) AS voyages_count,
    -- total measurements collected by this ship (across all voyages)
    (SELECT COUNT(*) 
       FROM voyages v2 JOIN measurements m2 ON m2.voyage_id = v2.id 
      WHERE v2.ship_id = s.id) AS measurements_count,
    -- date of last completed voyage (if any)
    (SELECT MAX(v3.actual_arrival_date) 
       FROM voyages v3 
      WHERE v3.ship_id = s.id AND v3.status = 'COMPLETED') AS last_completed_voyage
FROM ships s;

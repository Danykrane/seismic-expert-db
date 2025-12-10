-- Generate large volume of measurement records for voyages (simulating collected data).

-- 1. Nitrate measurements for RV Alpha's voyage (Atlantic Route):
--    Generate hourly nitrate values for 2024 (8760 readings).
INSERT INTO measurements (id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT uuid_generate_v4(),
       (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id=s.id WHERE s.name='RV Alpha'),
       (SELECT id FROM indicators WHERE name='Nitrate'),
       (SELECT d.id FROM devices d JOIN ship_equipment se ON d.id=se.device_id 
         JOIN ships sh ON se.ship_id=sh.id WHERE sh.name='RV Alpha' AND d.name LIKE 'Nitrate Sensor%'),
       NULL,  -- method_id will be set by trigger based on device and indicator
       (SELECT unit_id FROM indicators WHERE name='Nitrate'),
       5.0 + 15.0 * random(),  -- random nitrate value between 5.0 and 20.0 mg/L
       generate_series(TIMESTAMP '2024-01-01 00:00:00', TIMESTAMP '2024-12-31 23:00:00', INTERVAL '1 hour');

-- 2. Nitrate measurements for RV Beta's voyage (Pacific Route):
--    Generate hourly nitrate values for 2024 (8760 readings).
INSERT INTO measurements (id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT uuid_generate_v4(),
       (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id=s.id WHERE s.name='RV Beta'),
       (SELECT id FROM indicators WHERE name='Nitrate'),
       (SELECT d.id FROM devices d JOIN ship_equipment se ON d.id=se.device_id 
         JOIN ships sh ON se.ship_id=sh.id WHERE sh.name='RV Beta' AND d.name LIKE 'Nitrate Sensor%'),
       NULL,
       (SELECT unit_id FROM indicators WHERE name='Nitrate'),
       1.0 + 5.0 * random(),   -- random nitrate value between 1.0 and 6.0 mg/L (Pacific generally lower)
       generate_series(TIMESTAMP '2024-03-01 00:00:00', TIMESTAMP '2024-12-31 23:00:00', INTERVAL '1 hour');

-- 3. Nitrate measurements for RV Gamma's voyage (Baltic Route):
--    Generate daily nitrate values for 2024 (365 readings).
INSERT INTO measurements (id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT uuid_generate_v4(),
       (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id=s.id WHERE s.name='RV Gamma'),
       (SELECT id FROM indicators WHERE name='Nitrate'),
       (SELECT d.id FROM devices d JOIN ship_equipment se ON d.id=se.device_id 
         JOIN ships sh ON se.ship_id=sh.id WHERE sh.name='RV Gamma' AND d.name LIKE 'Nitrate Sensor%'),
       NULL,
       (SELECT unit_id FROM indicators WHERE name='Nitrate'),
       10.0 + 10.0 * random(),  -- random nitrate between 10.0 and 20.0 mg/L (Baltic higher nutrient levels)
       generate_series(TIMESTAMP '2024-05-15 00:00:00', TIMESTAMP '2024-12-31 00:00:00', INTERVAL '1 day');

-- 4. Temperature measurements for RV Gamma's voyage (Baltic Route):
--    Generate daily temperature values for 2024 (365 readings).
INSERT INTO measurements (id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT uuid_generate_v4(),
       (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id=s.id WHERE s.name='RV Gamma'),
       (SELECT id FROM indicators WHERE name='Temperature'),
       (SELECT d.id FROM devices d JOIN ship_equipment se ON d.id=se.device_id 
         JOIN ships sh ON se.ship_id=sh.id WHERE sh.name='RV Gamma' AND d.name LIKE 'Thermometer%'),
       NULL,
       (SELECT unit_id FROM indicators WHERE name='Temperature'),
       -1 + 5 * random(),  -- random temperature between -1 and 4 °C (cold Baltic conditions)
       generate_series(TIMESTAMP '2024-05-15 00:00:00', TIMESTAMP '2024-12-31 00:00:00', INTERVAL '1 day');

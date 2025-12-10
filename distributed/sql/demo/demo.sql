-- demo.sql
-- Демонстрационное заполнение таблиц для экспертной системы морских исследований.
-- ВАЖНО: предполагается, что схема БД уже создана (все 14 таблиц, тип voyage_status, триггеры, вьюхи).

BEGIN;

------------------------------------------------------------
-- 1. ЕДИНИЦЫ ИЗМЕРЕНИЯ
------------------------------------------------------------
INSERT INTO units (name, symbol)
VALUES
  ('Milligram per Liter', 'mg/L'),
  ('Degree Celsius', '°C'),
  ('pH scale (0-14)', 'pH')
ON CONFLICT (symbol) DO NOTHING;

------------------------------------------------------------
-- 2. СПИСОК ПОКАЗАТЕЛЕЙ (INDICATORS)
------------------------------------------------------------
INSERT INTO indicators (name, unit_id, normal_min, normal_max, description)
VALUES
  ('Nitrate',
   (SELECT id FROM units WHERE symbol = 'mg/L'),
   0, 50,
   'Nitrate concentration in water'),
  ('Temperature',
   (SELECT id FROM units WHERE symbol = '°C'),
   -10, 40,
   'Water temperature'),
  ('pH',
   (SELECT id FROM units WHERE symbol = 'pH'),
   0, 14,
   'Water acidity (0-14)')
ON CONFLICT (name) DO NOTHING;

------------------------------------------------------------
-- 3. ТИПЫ УСТРОЙСТВ ИЗМЕРЕНИЯ (DEVICE_TYPES)
------------------------------------------------------------
INSERT INTO device_types(name, description) VALUES
  ('Nitrate Sensor', 'In-situ nitrate measurement sensor'),
  ('Thermometer',    'Temperature measuring device'),
  ('pH Meter',       'Electronic pH measuring device')
ON CONFLICT (name) DO NOTHING;

------------------------------------------------------------
-- 4. МЕТОДИКИ ИЗМЕРЕНИЙ (METHODS)
------------------------------------------------------------
INSERT INTO methods(name, indicator_id, description)
VALUES
  ('UV Nitrate Sensor Method',
   (SELECT id FROM indicators WHERE name = 'Nitrate'),
   'UV optical method for nitrate sensors'),
  ('Thermometer Method',
   (SELECT id FROM indicators WHERE name = 'Temperature'),
   'Standard thermometer measurement method'),
  ('Electrode pH Method',
   (SELECT id FROM indicators WHERE name = 'pH'),
   'Glass electrode method for pH measurement')
ON CONFLICT (name) DO NOTHING;

------------------------------------------------------------
-- 5. ПРИМЕНЕНИЕ МЕТОДИК К ТИПАМ УСТРОЙСТВ (METHOD_USAGE)
------------------------------------------------------------
INSERT INTO method_usage(method_id, device_type_id)
VALUES
  ((SELECT id FROM methods WHERE name = 'UV Nitrate Sensor Method'),
   (SELECT id FROM device_types WHERE name = 'Nitrate Sensor')),
  ((SELECT id FROM methods WHERE name = 'Thermometer Method'),
   (SELECT id FROM device_types WHERE name = 'Thermometer')),
  ((SELECT id FROM methods WHERE name = 'Electrode pH Method'),
   (SELECT id FROM device_types WHERE name = 'pH Meter'))
ON CONFLICT (method_id, device_type_id) DO NOTHING;

------------------------------------------------------------
-- 6. КОНКРЕТНЫЕ УСТРОЙСТВА (DEVICES)
------------------------------------------------------------
INSERT INTO devices(name, device_type_id, description)
VALUES
  ('Nitrate Sensor #1',
   (SELECT id FROM device_types WHERE name = 'Nitrate Sensor'),
   'Nitrate sensor device (Unit 1)'),
  ('Nitrate Sensor #2',
   (SELECT id FROM device_types WHERE name = 'Nitrate Sensor'),
   'Nitrate sensor device (Unit 2)'),
  ('Nitrate Sensor #3',
   (SELECT id FROM device_types WHERE name = 'Nitrate Sensor'),
   'Nitrate sensor device (Unit 3)'),
  ('Thermometer #1',
   (SELECT id FROM device_types WHERE name = 'Thermometer'),
   'Thermometer device'),
  ('pH Meter #1',
   (SELECT id FROM device_types WHERE name = 'pH Meter'),
   'Electronic pH meter')
ON CONFLICT (name) DO NOTHING;

------------------------------------------------------------
-- 7. АКВАТОРИИ (AQUATORIES)
------------------------------------------------------------
INSERT INTO aquatories(name, type, description)
VALUES
  ('North Atlantic Ocean', 'Ocean', 'North Atlantic operational area'),
  ('North Pacific Ocean',  'Ocean', 'North Pacific operational area'),
  ('Baltic Sea',           'Sea',   'Baltic Sea operational area')
ON CONFLICT (name) DO NOTHING;

------------------------------------------------------------
-- 8. ПОРТЫ (PORTS)
------------------------------------------------------------
INSERT INTO ports(name, aquatory_id, country)
VALUES
  ('Halifax',
   (SELECT id FROM aquatories WHERE name = 'North Atlantic Ocean'),
   'Canada'),
  ('Lisbon',
   (SELECT id FROM aquatories WHERE name = 'North Atlantic Ocean'),
   'Portugal'),
  ('Tokyo',
   (SELECT id FROM aquatories WHERE name = 'North Pacific Ocean'),
   'Japan'),
  ('San Francisco',
   (SELECT id FROM aquatories WHERE name = 'North Pacific Ocean'),
   'USA'),
  ('Gdansk',
   (SELECT id FROM aquatories WHERE name = 'Baltic Sea'),
   'Poland'),
  ('Stockholm',
   (SELECT id FROM aquatories WHERE name = 'Baltic Sea'),
   'Sweden')
ON CONFLICT (name, aquatory_id) DO NOTHING;

------------------------------------------------------------
-- 9. СУДА (SHIPS)
------------------------------------------------------------
INSERT INTO ships(name, home_port_id, model, tonnage)
VALUES
  ('RV Alpha',
   (SELECT id FROM ports WHERE name = 'Halifax'),
   'Research Vessel', 10000),
  ('RV Beta',
   (SELECT id FROM ports WHERE name = 'Tokyo'),
   'Research Vessel', 9000),
  ('RV Gamma',
   (SELECT id FROM ports WHERE name = 'Gdansk'),
   'Research Vessel', 8000)
ON CONFLICT (name) DO NOTHING;

------------------------------------------------------------
-- 10. КОМПЛЕКТАЦИЯ СУДНА (SHIP_EQUIPMENT)
------------------------------------------------------------
INSERT INTO ship_equipment(ship_id, device_id, installed_on)
VALUES
  ((SELECT id FROM ships WHERE name = 'RV Alpha'),
   (SELECT id FROM devices WHERE name = 'Nitrate Sensor #1'),
   CURRENT_DATE),
  ((SELECT id FROM ships WHERE name = 'RV Beta'),
   (SELECT id FROM devices WHERE name = 'Nitrate Sensor #2'),
   CURRENT_DATE),
  ((SELECT id FROM ships WHERE name = 'RV Gamma'),
   (SELECT id FROM devices WHERE name = 'Nitrate Sensor #3'),
   CURRENT_DATE),
  ((SELECT id FROM ships WHERE name = 'RV Gamma'),
   (SELECT id FROM devices WHERE name = 'Thermometer #1'),
   CURRENT_DATE),
  ((SELECT id FROM ships WHERE name = 'RV Gamma'),
   (SELECT id FROM devices WHERE name = 'pH Meter #1'),
   CURRENT_DATE)
ON CONFLICT (ship_id, device_id) DO NOTHING;

------------------------------------------------------------
-- 11. МАРШРУТЫ (ROUTES)
------------------------------------------------------------
INSERT INTO routes(name, origin_port_id, dest_port_id, distance_nm, description)
VALUES
  ('Atlantic Route 1',
   (SELECT id FROM ports WHERE name = 'Halifax'),
   (SELECT id FROM ports WHERE name = 'Lisbon'),
   3000,
   'Trans-Atlantic research route'),
  ('Pacific Route 1',
   (SELECT id FROM ports WHERE name = 'Tokyo'),
   (SELECT id FROM ports WHERE name = 'San Francisco'),
   4700,
   'Trans-Pacific research route'),
  ('Baltic Route 1',
   (SELECT id FROM ports WHERE name = 'Gdansk'),
   (SELECT id FROM ports WHERE name = 'Stockholm'),
   400,
   'Baltic Sea research route')
ON CONFLICT (name) DO NOTHING;

------------------------------------------------------------
-- 12. РЕЙСЫ (VOYAGES)
------------------------------------------------------------
INSERT INTO voyages(ship_id, route_id, status,
                    planned_departure_date, planned_arrival_date,
                    actual_departure_date,  actual_arrival_date,
                    notes)
VALUES
  ((SELECT id FROM ships WHERE name = 'RV Alpha'),
   (SELECT id FROM routes WHERE name = 'Atlantic Route 1'),
   'COMPLETED',
   TIMESTAMP '2024-01-01 10:00:00',
   TIMESTAMP '2024-02-01 10:00:00',
   TIMESTAMP '2024-01-01 12:00:00',
   TIMESTAMP '2024-02-01 09:00:00',
   'Completed Atlantic research voyage'),
  ((SELECT id FROM ships WHERE name = 'RV Beta'),
   (SELECT id FROM routes WHERE name = 'Pacific Route 1'),
   'COMPLETED',
   TIMESTAMP '2024-03-01 08:00:00',
   TIMESTAMP '2024-04-01 08:00:00',
   TIMESTAMP '2024-03-01 08:30:00',
   TIMESTAMP '2024-04-01 07:45:00',
   'Completed Pacific research voyage'),
  ((SELECT id FROM ships WHERE name = 'RV Gamma'),
   (SELECT id FROM routes WHERE name = 'Baltic Route 1'),
   'COMPLETED',
   TIMESTAMP '2024-05-15 06:00:00',
   TIMESTAMP '2024-06-15 18:00:00',
   TIMESTAMP '2024-05-15 06:10:00',
   TIMESTAMP '2024-06-15 17:50:00',
   'Completed Baltic research voyage')
ON CONFLICT DO NOTHING;

------------------------------------------------------------
-- 13. ПЛАНИРУЕМЫЕ ПОКАЗАТЕЛИ ДЛЯ РЕЙСОВ (VOYAGE_INDICATORS)
------------------------------------------------------------
INSERT INTO voyage_indicators(voyage_id, indicator_id)
VALUES
  ((SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id
    WHERE s.name = 'RV Alpha'),
   (SELECT id FROM indicators WHERE name = 'Nitrate')),
  ((SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id
    WHERE s.name = 'RV Beta'),
   (SELECT id FROM indicators WHERE name = 'Nitrate')),
  ((SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id
    WHERE s.name = 'RV Gamma'),
   (SELECT id FROM indicators WHERE name = 'Nitrate')),
  ((SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id
    WHERE s.name = 'RV Gamma'),
   (SELECT id FROM indicators WHERE name = 'Temperature'))
ON CONFLICT (voyage_id, indicator_id) DO NOTHING;

------------------------------------------------------------
-- 14. ИЗМЕРЕННЫЕ ПОКАЗАТЕЛИ (MEASUREMENTS) — НЕБОЛЬШОЙ ДЕМО НАБОР
-- триггер fn_validate_measurement проверит:
--   - устройство подходит по методике,
--   - устройство стоит на этом судне,
--   - показатель входит в план рейса,
--   - значение в допустимых пределах.
------------------------------------------------------------

-- RV Alpha: 5 измерений нитратов
INSERT INTO measurements(voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT
  (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Alpha'),
  (SELECT id FROM indicators WHERE name = 'Nitrate'),
  (SELECT d.id FROM devices d
     JOIN ship_equipment se ON d.id = se.device_id
     JOIN ships s ON se.ship_id = s.id
    WHERE s.name = 'RV Alpha'
      AND d.name LIKE 'Nitrate Sensor%'),
  NULL,
  (SELECT unit_id FROM indicators WHERE name = 'Nitrate'),
  val,
  TIMESTAMP '2024-01-10 00:00:00' + (idx || ' hours')::interval
FROM (
  VALUES
    (0, 10.0),
    (1, 12.5),
    (2, 14.0),
    (3, 15.5),
    (4, 18.0)
) AS t(idx, val);

-- RV Beta: 5 измерений нитратов
INSERT INTO measurements(voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT
  (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Beta'),
  (SELECT id FROM indicators WHERE name = 'Nitrate'),
  (SELECT d.id FROM devices d
     JOIN ship_equipment se ON d.id = se.device_id
     JOIN ships s ON se.ship_id = s.id
    WHERE s.name = 'RV Beta'
      AND d.name LIKE 'Nitrate Sensor%'),
  NULL,
  (SELECT unit_id FROM indicators WHERE name = 'Nitrate'),
  val,
  TIMESTAMP '2024-03-10 00:00:00' + (idx || ' hours')::interval
FROM (
  VALUES
    (0, 3.0),
    (1, 4.2),
    (2, 5.1),
    (3, 4.8),
    (4, 3.5)
) AS t(idx, val);

-- RV Gamma: 5 измерений нитратов
INSERT INTO measurements(voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT
  (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Gamma'),
  (SELECT id FROM indicators WHERE name = 'Nitrate'),
  (SELECT d.id FROM devices d
     JOIN ship_equipment se ON d.id = se.device_id
     JOIN ships s ON se.ship_id = s.id
    WHERE s.name = 'RV Gamma'
      AND d.name LIKE 'Nitrate Sensor%'),
  NULL,
  (SELECT unit_id FROM indicators WHERE name = 'Nitrate'),
  val,
  TIMESTAMP '2024-05-20 00:00:00' + (idx || ' hours')::interval
FROM (
  VALUES
    (0, 11.0),
    (1, 12.0),
    (2, 13.5),
    (3, 15.0),
    (4, 16.2)
) AS t(idx, val);

-- RV Gamma: 5 измерений температуры
INSERT INTO measurements(voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at)
SELECT
  (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Gamma'),
  (SELECT id FROM indicators WHERE name = 'Temperature'),
  (SELECT d.id FROM devices d
     JOIN ship_equipment se ON d.id = se.device_id
     JOIN ships s ON se.ship_id = s.id
    WHERE s.name = 'RV Gamma'
      AND d.name LIKE 'Thermometer%'),
  NULL,
  (SELECT unit_id FROM indicators WHERE name = 'Temperature'),
  val,
  TIMESTAMP '2024-05-20 00:00:00' + (idx || ' hours')::interval
FROM (
  VALUES
    (0,  1.0),
    (1,  2.5),
    (2,  3.0),
    (3,  1.8),
    (4,  0.5)
) AS t(idx, val);

COMMIT;

------------------------------------------------------------
-- После запуска demo.sql можно проверить вьюхи:
-- SELECT * FROM top10_nitrate_locations;
-- SELECT * FROM expedition_report;
-- SELECT * FROM avg_param_values_by_month;
-- SELECT * FROM ship_report;
------------------------------------------------------------

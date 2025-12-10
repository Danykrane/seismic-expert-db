-- =========================================
-- A. Справочные данные (seed_full)
-- =========================================

-- 1. Единицы измерения
INSERT INTO units (id, name, symbol) VALUES
(uuid_generate_v4(), 'Milligram per Liter', 'mg/L'),
(uuid_generate_v4(), 'Degree Celsius',       '°C'),
(uuid_generate_v4(), 'pH scale (0-14)',      'pH');

-- 2. Показатели (indicators)
INSERT INTO indicators (id, name, unit_id, normal_min, normal_max, description)
VALUES
(
    uuid_generate_v4(),
    'Nitrate',
    (SELECT id FROM units WHERE symbol = 'mg/L'),
    0,
    50,
    'Nitrate concentration in water'
),
(
    uuid_generate_v4(),
    'Temperature',
    (SELECT id FROM units WHERE symbol = '°C'),
    -10,
    40,
    'Water temperature'
),
(
    uuid_generate_v4(),
    'pH',
    (SELECT id FROM units WHERE symbol = 'pH'),
    0,
    14,
    'Water pH level'
);

-- 3. Типы устройств
INSERT INTO device_types (id, name, description) VALUES
(uuid_generate_v4(), 'Nitrate Sensor', 'In-situ nitrate measurement sensor'),
(uuid_generate_v4(), 'Thermometer',    'Temperature measuring device'),
(uuid_generate_v4(), 'pH Meter',       'Electronic pH measuring device');

-- 4. Методики (по одному на каждый показатель)
INSERT INTO methods (id, name, indicator_id, description) VALUES
(
    uuid_generate_v4(),
    'UV Nitrate Sensor Method',
    (SELECT id FROM indicators WHERE name = 'Nitrate'),
    'UV optical method for nitrate sensors'
),
(
    uuid_generate_v4(),
    'Thermometer Method',
    (SELECT id FROM indicators WHERE name = 'Temperature'),
    'Standard thermometer measurement method'
),
(
    uuid_generate_v4(),
    'Electrode pH Method',
    (SELECT id FROM indicators WHERE name = 'pH'),
    'Glass electrode method for pH measurement'
);

-- 5. Применение методик (method_usage)
INSERT INTO method_usage (id, method_id, device_type_id) VALUES
(
    uuid_generate_v4(),
    (SELECT id FROM methods WHERE name = 'UV Nitrate Sensor Method'),
    (SELECT id FROM device_types WHERE name = 'Nitrate Sensor')
),
(
    uuid_generate_v4(),
    (SELECT id FROM methods WHERE name = 'Thermometer Method'),
    (SELECT id FROM device_types WHERE name = 'Thermometer')
),
(
    uuid_generate_v4(),
    (SELECT id FROM methods WHERE name = 'Electrode pH Method'),
    (SELECT id FROM device_types WHERE name = 'pH Meter')
);

-- 6. Устройства (конкретные экземпляры)
INSERT INTO devices (id, name, device_type_id, description) VALUES
(
    uuid_generate_v4(),
    'Nitrate Sensor #1',
    (SELECT id FROM device_types WHERE name = 'Nitrate Sensor'),
    'Nitrate sensor device (Unit 1)'
),
(
    uuid_generate_v4(),
    'Nitrate Sensor #2',
    (SELECT id FROM device_types WHERE name = 'Nitrate Sensor'),
    'Nitrate sensor device (Unit 2)'
),
(
    uuid_generate_v4(),
    'Nitrate Sensor #3',
    (SELECT id FROM device_types WHERE name = 'Nitrate Sensor'),
    'Nitrate sensor device (Unit 3)'
),
(
    uuid_generate_v4(),
    'Thermometer #1',
    (SELECT id FROM device_types WHERE name = 'Thermometer'),
    'Thermometer device'
),
(
    uuid_generate_v4(),
    'pH Meter #1',
    (SELECT id FROM device_types WHERE name = 'pH Meter'),
    'Electronic pH meter device'
);

-- 7. Акватории
INSERT INTO aquatories (id, name, type) VALUES
(uuid_generate_v4(), 'North Atlantic Ocean', 'Ocean'),
(uuid_generate_v4(), 'North Pacific Ocean',  'Ocean'),
(uuid_generate_v4(), 'Baltic Sea',           'Sea');

-- 8. Порты
INSERT INTO ports (id, name, aquatory_id, country) VALUES
(
    uuid_generate_v4(),
    'Halifax',
    (SELECT id FROM aquatories WHERE name = 'North Atlantic Ocean'),
    'Canada'
),
(
    uuid_generate_v4(),
    'Lisbon',
    (SELECT id FROM aquatories WHERE name = 'North Atlantic Ocean'),
    'Portugal'
),
(
    uuid_generate_v4(),
    'Tokyo',
    (SELECT id FROM aquatories WHERE name = 'North Pacific Ocean'),
    'Japan'
),
(
    uuid_generate_v4(),
    'San Francisco',
    (SELECT id FROM aquatories WHERE name = 'North Pacific Ocean'),
    'USA'
),
(
    uuid_generate_v4(),
    'Gdansk',
    (SELECT id FROM aquatories WHERE name = 'Baltic Sea'),
    'Poland'
),
(
    uuid_generate_v4(),
    'Stockholm',
    (SELECT id FROM aquatories WHERE name = 'Baltic Sea'),
    'Sweden'
);

-- 9. Суда
INSERT INTO ships (id, name, home_port_id) VALUES
(
    uuid_generate_v4(),
    'RV Alpha',
    (SELECT id FROM ports WHERE name = 'Halifax')
),
(
    uuid_generate_v4(),
    'RV Beta',
    (SELECT id FROM ports WHERE name = 'Tokyo')
),
(
    uuid_generate_v4(),
    'RV Gamma',
    (SELECT id FROM ports WHERE name = 'Gdansk')
);

-- 10. Комплектация судов
INSERT INTO ship_equipment (id, ship_id, device_id, installed_on) VALUES
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Alpha'),
    (SELECT id FROM devices WHERE name = 'Nitrate Sensor #1'),
    CURRENT_DATE
),
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Beta'),
    (SELECT id FROM devices WHERE name = 'Nitrate Sensor #2'),
    CURRENT_DATE
),
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Gamma'),
    (SELECT id FROM devices WHERE name = 'Nitrate Sensor #3'),
    CURRENT_DATE
),
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Gamma'),
    (SELECT id FROM devices WHERE name = 'Thermometer #1'),
    CURRENT_DATE
),
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Gamma'),
    (SELECT id FROM devices WHERE name = 'pH Meter #1'),
    CURRENT_DATE
);

-- 11. Маршруты
INSERT INTO routes (id, name, origin_port_id, dest_port_id, distance_nm) VALUES
(
    uuid_generate_v4(),
    'Atlantic Route 1',
    (SELECT id FROM ports WHERE name = 'Halifax'),
    (SELECT id FROM ports WHERE name = 'Lisbon'),
    3000
),
(
    uuid_generate_v4(),
    'Pacific Route 1',
    (SELECT id FROM ports WHERE name = 'Tokyo'),
    (SELECT id FROM ports WHERE name = 'San Francisco'),
    4700
),
(
    uuid_generate_v4(),
    'Baltic Route 1',
    (SELECT id FROM ports WHERE name = 'Gdansk'),
    (SELECT id FROM ports WHERE name = 'Stockholm'),
    400
);

-- 12. Рейсы (voyages) — по одному на каждый маршрут/судно
INSERT INTO voyages (
    id, ship_id, route_id, status,
    planned_departure_date, planned_arrival_date,
    actual_departure_date, actual_arrival_date, notes
) VALUES
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Alpha'),
    (SELECT id FROM routes WHERE name = 'Atlantic Route 1'),
    'COMPLETED',
    '2024-01-01 10:00:00',
    '2024-02-01 10:00:00',
    '2024-01-01 12:00:00',
    '2024-02-01 09:00:00',
    'Completed Atlantic research voyage'
),
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Beta'),
    (SELECT id FROM routes WHERE name = 'Pacific Route 1'),
    'COMPLETED',
    '2024-03-01 08:00:00',
    '2024-04-01 08:00:00',
    '2024-03-01 08:30:00',
    '2024-04-01 07:45:00',
    'Completed Pacific research voyage'
),
(
    uuid_generate_v4(),
    (SELECT id FROM ships WHERE name = 'RV Gamma'),
    (SELECT id FROM routes WHERE name = 'Baltic Route 1'),
    'COMPLETED',
    '2024-05-15 06:00:00',
    '2024-06-15 18:00:00',
    '2024-05-15 06:10:00',
    '2024-06-15 17:50:00',
    'Completed Baltic research voyage'
);

-- 13. Измеряемые показатели (план на рейс)
INSERT INTO voyage_indicators (id, voyage_id, indicator_id) VALUES
(
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Alpha'),
    (SELECT id FROM indicators WHERE name = 'Nitrate')
),
(
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Beta'),
    (SELECT id FROM indicators WHERE name = 'Nitrate')
),
(
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Gamma'),
    (SELECT id FROM indicators WHERE name = 'Nitrate')
),
(
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Gamma'),
    (SELECT id FROM indicators WHERE name = 'Temperature')
);

-- =========================================
-- B. Большой объём измерений (seed_bulk)
-- =========================================

-- Нитраты: RV Alpha, каждый час за год
INSERT INTO measurements (
    id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at
)
SELECT
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Alpha'),
    (SELECT id FROM indicators WHERE name = 'Nitrate'),
    (SELECT d.id FROM devices d
      JOIN ship_equipment se ON d.id = se.device_id
      JOIN ships sh ON se.ship_id = sh.id
     WHERE sh.name = 'RV Alpha' AND d.name LIKE 'Nitrate Sensor%'),
    NULL,
    (SELECT unit_id FROM indicators WHERE name = 'Nitrate'),
    5.0 + 15.0 * random(),
    generate_series(
        TIMESTAMP '2024-01-01 00:00:00',
        TIMESTAMP '2024-12-31 23:00:00',
        INTERVAL '1 hour'
    );

-- Нитраты: RV Beta, каждый час (значения ниже)
INSERT INTO measurements (
    id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at
)
SELECT
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Beta'),
    (SELECT id FROM indicators WHERE name = 'Nitrate'),
    (SELECT d.id FROM devices d
      JOIN ship_equipment se ON d.id = se.device_id
      JOIN ships sh ON se.ship_id = sh.id
     WHERE sh.name = 'RV Beta' AND d.name LIKE 'Nitrate Sensor%'),
    NULL,
    (SELECT unit_id FROM indicators WHERE name = 'Nitrate'),
    1.0 + 5.0 * random(),
    generate_series(
        TIMESTAMP '2024-03-01 00:00:00',
        TIMESTAMP '2024-12-31 23:00:00',
        INTERVAL '1 hour'
    );

-- Нитраты: RV Gamma, раз в день
INSERT INTO measurements (
    id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at
)
SELECT
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Gamma'),
    (SELECT id FROM indicators WHERE name = 'Nitrate'),
    (SELECT d.id FROM devices d
      JOIN ship_equipment se ON d.id = se.device_id
      JOIN ships sh ON se.ship_id = sh.id
     WHERE sh.name = 'RV Gamma' AND d.name LIKE 'Nitrate Sensor%'),
    NULL,
    (SELECT unit_id FROM indicators WHERE name = 'Nitrate'),
    10.0 + 10.0 * random(),
    generate_series(
        TIMESTAMP '2024-05-15 00:00:00',
        TIMESTAMP '2024-12-31 00:00:00',
        INTERVAL '1 day'
    );

-- Температура: RV Gamma, раз в день
INSERT INTO measurements (
    id, voyage_id, indicator_id, device_id, method_id, unit_id, value, measured_at
)
SELECT
    uuid_generate_v4(),
    (SELECT v.id FROM voyages v JOIN ships s ON v.ship_id = s.id WHERE s.name = 'RV Gamma'),
    (SELECT id FROM indicators WHERE name = 'Temperature'),
    (SELECT d.id FROM devices d
      JOIN ship_equipment se ON d.id = se.device_id
      JOIN ships sh ON se.ship_id = sh.id
     WHERE sh.name = 'RV Gamma' AND d.name LIKE 'Thermometer%'),
    NULL,
    (SELECT unit_id FROM indicators WHERE name = 'Temperature'),
    -1 + 5 * random(),
    generate_series(
        TIMESTAMP '2024-05-15 00:00:00',
        TIMESTAMP '2024-12-31 00:00:00',
        INTERVAL '1 day'
    );

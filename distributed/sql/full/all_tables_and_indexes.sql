-- ========================================
-- 0. Расширение для UUID
-- ========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ========================================
-- 1. Типы
-- ========================================

-- Тип статуса рейса (voyage)
CREATE TYPE voyage_status AS ENUM ('PLANNED', 'ONGOING', 'COMPLETED');

-- ========================================
-- 2. Таблицы справочников и объектов
-- ========================================

-- 2.1 Акватории (Aquatories)
CREATE TABLE aquatories (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,
    type        TEXT,
    description TEXT
);

-- 2.2 Порты (Ports)
CREATE TABLE ports (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL,
    aquatory_id UUID NOT NULL,
    country     TEXT,
    UNIQUE(name, aquatory_id),
    CONSTRAINT fk_port_aquatory
        FOREIGN KEY (aquatory_id) REFERENCES aquatories(id) ON DELETE RESTRICT
);

-- 2.3 Единицы измерения (Units)
CREATE TABLE units (
    id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name    TEXT NOT NULL UNIQUE,
    symbol  TEXT NOT NULL UNIQUE
);

-- 2.4 Показатели (Indicators – список показателей)
CREATE TABLE indicators (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,
    unit_id     UUID NOT NULL,
    normal_min  NUMERIC,
    normal_max  NUMERIC,
    description TEXT,
    CONSTRAINT fk_indicator_unit
        FOREIGN KEY (unit_id) REFERENCES units(id) ON DELETE RESTRICT
);

-- 2.5 Типы устройств измерения (Device types)
CREATE TABLE device_types (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,
    description TEXT
);

-- 2.6 Методики измерения показателей (Methods)
CREATE TABLE methods (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         TEXT NOT NULL UNIQUE,
    indicator_id UUID NOT NULL,
    description  TEXT,
    CONSTRAINT fk_method_indicator
        FOREIGN KEY (indicator_id) REFERENCES indicators(id) ON DELETE RESTRICT
);

-- 2.7 Применение методик (Method usage – связь методики и типа устройства)
CREATE TABLE method_usage (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    method_id      UUID NOT NULL,
    device_type_id UUID NOT NULL,
    CONSTRAINT fk_method_usage_method
        FOREIGN KEY (method_id) REFERENCES methods(id) ON DELETE CASCADE,
    CONSTRAINT fk_method_usage_device_type
        FOREIGN KEY (device_type_id) REFERENCES device_types(id) ON DELETE CASCADE,
    UNIQUE (method_id, device_type_id)
);

-- 2.8 Устройства измерения (Devices – конкретные приборы)
CREATE TABLE devices (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name           TEXT NOT NULL UNIQUE,
    device_type_id UUID NOT NULL,
    description    TEXT,
    CONSTRAINT fk_device_type
        FOREIGN KEY (device_type_id) REFERENCES device_types(id) ON DELETE RESTRICT
);

-- 2.9 Суда (Ships)
CREATE TABLE ships (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         TEXT NOT NULL UNIQUE,
    model        TEXT,
    tonnage      NUMERIC,
    home_port_id UUID,
    CONSTRAINT fk_ship_home_port
        FOREIGN KEY (home_port_id) REFERENCES ports(id) ON DELETE SET NULL
);

-- 2.10 Комплектация судна (Ship equipment – какие устройства на каком судне)
CREATE TABLE ship_equipment (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ship_id     UUID NOT NULL,
    device_id   UUID NOT NULL,
    installed_on DATE,
    removed_on   DATE,
    CONSTRAINT fk_equipment_ship
        FOREIGN KEY (ship_id) REFERENCES ships(id) ON DELETE CASCADE,
    CONSTRAINT fk_equipment_device
        FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    UNIQUE (ship_id, device_id)
);

-- 2.11 Маршруты (Routes)
CREATE TABLE routes (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name           TEXT NOT NULL UNIQUE,
    origin_port_id UUID NOT NULL,
    dest_port_id   UUID NOT NULL,
    distance_nm    NUMERIC,
    description    TEXT,
    CONSTRAINT fk_route_origin
        FOREIGN KEY (origin_port_id) REFERENCES ports(id) ON DELETE RESTRICT,
    CONSTRAINT fk_route_dest
        FOREIGN KEY (dest_port_id) REFERENCES ports(id) ON DELETE RESTRICT
);

-- 2.12 Рейсы (Voyages)
CREATE TABLE voyages (
    id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ship_id                UUID NOT NULL,
    route_id               UUID NOT NULL,
    status                 voyage_status NOT NULL DEFAULT 'PLANNED',
    planned_departure_date TIMESTAMP,
    planned_arrival_date   TIMESTAMP,
    actual_departure_date  TIMESTAMP,
    actual_arrival_date    TIMESTAMP,
    notes                  TEXT,
    CONSTRAINT fk_voyage_ship
        FOREIGN KEY (ship_id) REFERENCES ships(id) ON DELETE RESTRICT,
    CONSTRAINT fk_voyage_route
        FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE RESTRICT
);

-- 2.13 Измеряемые показатели для рейса (Voyage_indicators – план измерений)
CREATE TABLE voyage_indicators (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    voyage_id    UUID NOT NULL,
    indicator_id UUID NOT NULL,
    CONSTRAINT fk_vi_voyage
        FOREIGN KEY (voyage_id) REFERENCES voyages(id) ON DELETE CASCADE,
    CONSTRAINT fk_vi_indicator
        FOREIGN KEY (indicator_id) REFERENCES indicators(id) ON DELETE RESTRICT,
    UNIQUE (voyage_id, indicator_id)
);

-- 2.14 Измеренные показатели (Measurements – фактические данные)
CREATE TABLE measurements (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    voyage_id    UUID NOT NULL,
    indicator_id UUID NOT NULL,
    device_id    UUID,
    method_id    UUID,
    unit_id      UUID NOT NULL,
    value        NUMERIC NOT NULL,
    measured_at  TIMESTAMP NOT NULL,
    CONSTRAINT fk_measurement_voyage
        FOREIGN KEY (voyage_id) REFERENCES voyages(id) ON DELETE CASCADE,
    CONSTRAINT fk_measurement_indicator
        FOREIGN KEY (indicator_id) REFERENCES indicators(id) ON DELETE RESTRICT,
    CONSTRAINT fk_measurement_device
        FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
    CONSTRAINT fk_measurement_method
        FOREIGN KEY (method_id) REFERENCES methods(id) ON DELETE SET NULL,
    CONSTRAINT fk_measurement_unit
        FOREIGN KEY (unit_id) REFERENCES units(id) ON DELETE RESTRICT
);

-- Вспомогательная таблица логов (не входит в 14 основных, но нужна для триггеров)
CREATE TABLE logs (
    id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    log_time  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    entity    TEXT,
    entity_id UUID,
    operation TEXT,
    message   TEXT
);

-- ========================================
-- 3. Функции триггеров
-- ========================================

-- 3.1 Валидация измерений (measurement)
CREATE OR REPLACE FUNCTION fn_validate_measurement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS '
DECLARE
    ship_of_voyage UUID;
    expected_count INT;
    method_match   UUID;
    ind_min        NUMERIC;
    ind_max        NUMERIC;
BEGIN
    -- Должен быть указан либо прибор, либо метод (хотя бы один источник)
    IF NEW.device_id IS NULL AND NEW.method_id IS NULL THEN
        RAISE EXCEPTION ''Measurement %: either device_id or method_id must be provided'', NEW.id;
    END IF;

    -- Если указан прибор, но не указан метод — пытаемся подобрать метод через тип прибора и показатель
    IF NEW.device_id IS NOT NULL THEN
        SELECT mu.method_id
          INTO method_match
          FROM devices d
          JOIN device_types dt ON d.device_type_id = dt.id
          JOIN method_usage mu ON mu.device_type_id = dt.id
          JOIN methods m ON m.id = mu.method_id
         WHERE d.id = NEW.device_id
           AND m.indicator_id = NEW.indicator_id
         LIMIT 1;

        IF method_match IS NULL THEN
            RAISE EXCEPTION ''Measurement %: Device % is not capable of measuring indicator %'',
                NEW.id, NEW.device_id, NEW.indicator_id;
        END IF;

        -- Если метод не задан — проставляем найденный
        IF NEW.method_id IS NULL THEN
            NEW.method_id := method_match;
        ELSE
            -- Если метод задан, проверяем, что он соответствует прибору для данного показателя
            IF NEW.method_id <> method_match THEN
                RAISE EXCEPTION ''Measurement %: Provided method % does not match device % for indicator %'',
                    NEW.id, NEW.method_id, NEW.device_id, NEW.indicator_id;
            END IF;
        END IF;
    ELSE
        -- Прибор не указан, метод обязателен и должен соответствовать показателю
        SELECT indicator_id INTO method_match
          FROM methods
         WHERE id = NEW.method_id;

        IF method_match IS NULL THEN
            RAISE EXCEPTION ''Measurement %: Method % not found'', NEW.id, NEW.method_id;
        ELSIF method_match <> NEW.indicator_id THEN
            RAISE EXCEPTION ''Measurement %: Method % is for indicator %, does not match indicator % of measurement'',
                NEW.id, NEW.method_id, method_match, NEW.indicator_id;
        END IF;
    END IF;

    -- Проверяем, что прибор (если задан) действительно стоит на судне этого рейса
    IF NEW.device_id IS NOT NULL THEN
        SELECT v.ship_id INTO ship_of_voyage
          FROM voyages v
         WHERE v.id = NEW.voyage_id;

        IF ship_of_voyage IS NULL THEN
            RAISE EXCEPTION ''Measurement %: Voyage % does not exist'', NEW.id, NEW.voyage_id;
        END IF;

        PERFORM 1
          FROM ship_equipment se
         WHERE se.ship_id = ship_of_voyage
           AND se.device_id = NEW.device_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION ''Measurement %: Device % is not assigned to the ship % for voyage %'',
                NEW.id, NEW.device_id, ship_of_voyage, NEW.voyage_id;
        END IF;
    END IF;

    -- Проверяем, что показатель входит в план измерений рейса (если план вообще задан)
    SELECT COUNT(*) INTO expected_count
      FROM voyage_indicators vi
     WHERE vi.voyage_id = NEW.voyage_id;

    IF expected_count > 0 THEN
        PERFORM 1
          FROM voyage_indicators vi
         WHERE vi.voyage_id = NEW.voyage_id
           AND vi.indicator_id = NEW.indicator_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION ''Measurement %: Indicator % was not planned for voyage %'',
                NEW.id, NEW.indicator_id, NEW.voyage_id;
        END IF;
    END IF;

    -- Проверяем, что значение в пределах норм (если они заданы)
    SELECT normal_min, normal_max
      INTO ind_min, ind_max
      FROM indicators
     WHERE id = NEW.indicator_id;

    IF ind_min IS NOT NULL AND NEW.value < ind_min THEN
        RAISE EXCEPTION ''Measurement %: Value % is below the minimum % for indicator %'',
            NEW.id, NEW.value, ind_min, NEW.indicator_id;
    END IF;

    IF ind_max IS NOT NULL AND NEW.value > ind_max THEN
        RAISE EXCEPTION ''Measurement %: Value % exceeds the maximum % for indicator %'',
            NEW.id, NEW.value, ind_max, NEW.indicator_id;
    END IF;

    RETURN NEW;
END;
';

-- 3.2 Валидация статуса рейса (voyages)
CREATE OR REPLACE FUNCTION fn_validate_voyage_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS '
BEGIN
    -- Обрабатываем только изменение статуса
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        -- Разрешённые переходы: PLANNED -> ONGOING -> COMPLETED
        IF NOT (
            (OLD.status = ''PLANNED'' AND NEW.status = ''ONGOING'') OR
            (OLD.status = ''ONGOING'' AND NEW.status = ''COMPLETED'')
        ) THEN
            RAISE EXCEPTION ''Voyage %: invalid status transition from % to %'',
                NEW.id, OLD.status, NEW.status;
        END IF;

        -- Переход в ONGOING – ставим фактическое время выхода, если не задано
        IF NEW.status = ''ONGOING'' THEN
            IF NEW.actual_departure_date IS NULL THEN
                NEW.actual_departure_date := CURRENT_TIMESTAMP;
            END IF;
        ELSIF NEW.status = ''COMPLETED'' THEN
            -- Переход в COMPLETED – ставим фактическое время прибытия, если не задано
            IF NEW.actual_arrival_date IS NULL THEN
                NEW.actual_arrival_date := CURRENT_TIMESTAMP;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
';

-- 3.3 Логирование создания рейса
CREATE OR REPLACE FUNCTION fn_log_voyage_created()
RETURNS TRIGGER
LANGUAGE plpgsql
AS '
DECLARE
    ship_name  TEXT;
    route_name TEXT;
BEGIN
    SELECT s.name, r.name
      INTO ship_name, route_name
      FROM ships s, routes r
     WHERE s.id = NEW.ship_id
       AND r.id = NEW.route_id;

    INSERT INTO logs(entity, entity_id, operation, message)
    VALUES (
        ''voyage'',
        NEW.id,
        ''INSERT'',
        format(
            ''Voyage %s created: Ship="%s", Route="%s", Status=%s'',
            NEW.id, ship_name, route_name, NEW.status
        )
    );

    RETURN NEW;
END;
';

-- 3.4 Логирование изменения статуса рейса
CREATE OR REPLACE FUNCTION fn_log_voyage_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS '
BEGIN
    INSERT INTO logs(entity, entity_id, operation, message)
    VALUES (
        ''voyage'',
        NEW.id,
        ''UPDATE'',
        format(
            ''Voyage %s status changed from %s to %s'',
            NEW.id, OLD.status, NEW.status
        )
    );

    RETURN NEW;
END;
';

-- ========================================
-- 4. Сами триггеры
-- ========================================

-- Валидация измерений
CREATE TRIGGER trg_measurement_validate
BEFORE INSERT OR UPDATE ON measurements
FOR EACH ROW
EXECUTE PROCEDURE fn_validate_measurement();

-- Валидация статусов рейсов
CREATE TRIGGER trg_voyage_status_validate
BEFORE UPDATE ON voyages
FOR EACH ROW
EXECUTE PROCEDURE fn_validate_voyage_status();

-- Логирование создания рейса
CREATE TRIGGER trg_voyage_log_create
AFTER INSERT ON voyages
FOR EACH ROW
EXECUTE PROCEDURE fn_log_voyage_created();

-- Логирование изменения статуса рейса
CREATE TRIGGER trg_voyage_log_status
AFTER UPDATE OF status ON voyages
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE PROCEDURE fn_log_voyage_status_change();

-- ========================================
-- 5. Представления (Views)
-- ========================================

-- 5.1 Топ-10 локаций по среднему нитрату
CREATE OR REPLACE VIEW top10_nitrate_locations AS
SELECT 
    p.name  AS port,
    aq.name AS aquatory,
    AVG(m.value) AS avg_nitrate
FROM measurements m
JOIN indicators ind ON ind.id = m.indicator_id
JOIN voyages v      ON v.id = m.voyage_id
JOIN routes r       ON r.id = v.route_id
JOIN ports p        ON p.id = r.dest_port_id
JOIN aquatories aq  ON aq.id = p.aquatory_id
WHERE ind.name = 'Nitrate'
GROUP BY p.name, aq.name
ORDER BY AVG(m.value) DESC
LIMIT 10;

-- 5.2 Отчёт по экспедициям (рейсам)
CREATE OR REPLACE VIEW expedition_report AS
SELECT 
    v.id                    AS voyage_id,
    s.name                  AS ship,
    r.name                  AS route,
    v.actual_departure_date,
    v.actual_arrival_date,
    (v.actual_arrival_date - v.actual_departure_date) AS duration,
    COALESCE(COUNT(m.id), 0)               AS total_measurements,
    COUNT(DISTINCT m.indicator_id)         AS distinct_parameters
FROM voyages v
JOIN ships s   ON s.id = v.ship_id
JOIN routes r  ON r.id = v.route_id
LEFT JOIN measurements m ON m.voyage_id = v.id
WHERE v.status = 'COMPLETED'
GROUP BY v.id, s.name, r.name, v.actual_departure_date, v.actual_arrival_date;

-- 5.3 Средние значения показателей по месяцам
CREATE OR REPLACE VIEW avg_param_values_by_month AS
SELECT 
    ind.name                                     AS indicator,
    EXTRACT(YEAR  FROM m.measured_at)::INT       AS year,
    EXTRACT(MONTH FROM m.measured_at)::INT       AS month,
    ROUND(AVG(m.value)::NUMERIC, 3)              AS avg_value
FROM measurements m
JOIN indicators ind ON ind.id = m.indicator_id
GROUP BY ind.name,
         EXTRACT(YEAR  FROM m.measured_at),
         EXTRACT(MONTH FROM m.measured_at)
ORDER BY ind.name, year, month;

-- 5.4 Отчёт по судам
CREATE OR REPLACE VIEW ship_report AS
SELECT 
    s.name AS ship,
    -- сколько рейсов у судна
    (SELECT COUNT(*) FROM voyages v WHERE v.ship_id = s.id) AS voyages_count,
    -- сколько измерений собрано судном
    (SELECT COUNT(*)
       FROM voyages v2
       JOIN measurements m2 ON m2.voyage_id = v2.id
      WHERE v2.ship_id = s.id) AS measurements_count,
    -- дата последнего завершённого рейса
    (SELECT MAX(v3.actual_arrival_date)
       FROM voyages v3
      WHERE v3.ship_id = s.id
        AND v3.status = 'COMPLETED') AS last_completed_voyage
FROM ships s;

-- ========================================
-- Конец скрипта
-- ========================================

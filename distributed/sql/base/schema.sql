-- ========================================
-- Reference Data Tables (Central Node)
-- These tables hold static reference data such as geography, 
-- equipment, measurement units, indicators, and methodologies.
-- In a distributed setup, this data resides at the central node.
-- ========================================

-- Table: Aquatories (Акватории)
-- Description: Maritime regions or water areas. Each port belongs to one aquatory.
CREATE TABLE aquatories (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,
    type        TEXT,              -- e.g., Ocean, Sea, Gulf (if needed)
    description TEXT
);

-- Table: Ports (Порты)
-- Description: Ports located in aquatories. Each port references its aquatory.
CREATE TABLE ports (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          TEXT NOT NULL,
    aquatory_id   UUID NOT NULL,
    country       TEXT,
    UNIQUE(name, aquatory_id),  -- unique port name within an aquatory
    CONSTRAINT fk_port_aquatory FOREIGN KEY(aquatory_id) 
        REFERENCES aquatories(id) ON DELETE RESTRICT
        -- Each port is located in one aquatory; cannot delete aquatory if ports exist.
);

-- Table: Units of Measurement (Единицы измерения)
-- Description: Units for measured parameters (e.g., mg/L, °C, pH).
CREATE TABLE units (
    id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name    TEXT NOT NULL UNIQUE,   -- Full name or description (e.g., "milligram per liter")
    symbol  TEXT NOT NULL UNIQUE    -- Symbol or abbreviation (e.g., "mg/L")
);

-- Table: Indicators (Список показателей)
-- Description: List of measurable parameters/indicators (e.g., Nitrate, Temperature, pH).
CREATE TABLE indicators (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,   -- Name of the indicator (e.g., "Nitrate")
    unit_id     UUID NOT NULL,          -- Default/primary unit for this indicator
    normal_min  NUMERIC,                -- Optional: normal/valid range minimum
    normal_max  NUMERIC,                -- Optional: normal/valid range maximum
    description TEXT,
    CONSTRAINT fk_indicator_unit FOREIGN KEY(unit_id) 
        REFERENCES units(id) ON DELETE RESTRICT
        -- Each indicator is measured in one unit; cannot delete unit if in use.
);

-- Table: Device Types (Типы устройств измерения)
-- Description: Types/categories of measurement devices.
CREATE TABLE device_types (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,   -- e.g., "Nitrate Sensor", "Thermometer"
    description TEXT
    -- (If a device type is specialized for an indicator, that relationship is defined via method_usage)
);

-- Table: Measurement Methods (Методики измерения показателей)
-- Description: Methodologies for measuring indicators. Each method typically corresponds to a specific indicator.
CREATE TABLE methods (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          TEXT NOT NULL UNIQUE,   -- e.g., "UV Nitrate Sensor", "Glass Electrode pH"
    indicator_id  UUID NOT NULL,          -- The indicator this method measures
    description   TEXT,
    CONSTRAINT fk_method_indicator FOREIGN KEY(indicator_id)
        REFERENCES indicators(id) ON DELETE RESTRICT
        -- Cannot delete an indicator if a method exists for it.
);

-- Table: Method Usage (Применение методик)
-- Description: Mapping of measurement methods to device types that implement them.
-- Many-to-many relationship: which device types can use which methods.
CREATE TABLE method_usage (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    method_id      UUID NOT NULL,
    device_type_id UUID NOT NULL,
    CONSTRAINT fk_method_usage_method FOREIGN KEY(method_id)
        REFERENCES methods(id) ON DELETE CASCADE,
    CONSTRAINT fk_method_usage_device_type FOREIGN KEY(device_type_id)
        REFERENCES device_types(id) ON DELETE CASCADE,
    UNIQUE(method_id, device_type_id)
        -- Each combination of method and device type is listed at most once.
);

-- Table: Devices (Устройства измерения)
-- Description: Individual measurement devices. Each has a type and can be deployed on ships.
CREATE TABLE devices (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          TEXT NOT NULL UNIQUE,   -- identifier or serial number for the device
    device_type_id UUID NOT NULL,
    description   TEXT,
    CONSTRAINT fk_device_type FOREIGN KEY(device_type_id)
        REFERENCES device_types(id) ON DELETE RESTRICT
        -- Cannot delete a device type if devices of that type exist.
);

-- ========================================
-- Core Entity Tables (Workflow Data)
-- These tables represent dynamic data in the workflow.
-- Routes and voyages are synchronized between central and port nodes.
-- Ships and their equipment may be managed centrally and/or at ports.
-- ========================================

-- Table: Ships (Суда)
-- Description: Ships/vessels that carry out voyages. 
CREATE TABLE ships (
    id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name      TEXT NOT NULL UNIQUE,  -- ship name or identifier
    model     TEXT,
    tonnage   NUMERIC,
    home_port_id UUID,
    CONSTRAINT fk_ship_home_port FOREIGN KEY(home_port_id)
        REFERENCES ports(id) ON DELETE SET NULL
        -- Home port of ship (if any); if port removed, clear this reference.
);

-- Table: Ship Equipment (Комплектация судна)
-- Description: Equipment assignment of devices to ships (which devices are on which ship).
CREATE TABLE ship_equipment (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ship_id    UUID NOT NULL,
    device_id  UUID NOT NULL,
    installed_on DATE,
    removed_on   DATE,
    CONSTRAINT fk_equipment_ship FOREIGN KEY(ship_id)
        REFERENCES ships(id) ON DELETE CASCADE,
    CONSTRAINT fk_equipment_device FOREIGN KEY(device_id)
        REFERENCES devices(id) ON DELETE CASCADE,
    UNIQUE(ship_id, device_id)
        -- A specific device can be assigned to a ship only once at a time.
        -- (If a device moves ships, removed_on can be set and a new record inserted for new ship)
);

-- Table: Routes (Маршруты)
-- Description: Predefined routes (itineraries) usually between an origin and destination port.
-- In a distributed context, routes are shared between central and port databases.
CREATE TABLE routes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL UNIQUE,  -- route identifier
    origin_port_id  UUID NOT NULL,
    dest_port_id    UUID NOT NULL,
    distance_nm     NUMERIC,    -- distance in nautical miles (optional)
    description     TEXT,
    CONSTRAINT fk_route_origin FOREIGN KEY(origin_port_id)
        REFERENCES ports(id) ON DELETE RESTRICT,
    CONSTRAINT fk_route_dest FOREIGN KEY(dest_port_id)
        REFERENCES ports(id) ON DELETE RESTRICT
        -- Do not allow deleting ports if they are used in routes.
);

-- User-defined type: Voyage Status (for voyage state)
CREATE TYPE voyage_status AS ENUM ('PLANNED', 'ONGOING', 'COMPLETED');

-- Table: Voyages (Рейсы)
-- Description: A voyage (expedition) by a ship along a route. 
-- Voyages are synchronized between central and ports (two-way).
CREATE TABLE voyages (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ship_id               UUID NOT NULL,
    route_id              UUID NOT NULL,
    status                voyage_status NOT NULL DEFAULT 'PLANNED',
    planned_departure_date TIMESTAMP,
    planned_arrival_date   TIMESTAMP,
    actual_departure_date  TIMESTAMP,
    actual_arrival_date    TIMESTAMP,
    notes                 TEXT,
    CONSTRAINT fk_voyage_ship FOREIGN KEY(ship_id)
        REFERENCES ships(id) ON DELETE RESTRICT,
    CONSTRAINT fk_voyage_route FOREIGN KEY(route_id)
        REFERENCES routes(id) ON DELETE RESTRICT
        -- If needed, deleting a ship or route with voyages could be restricted (data preservation).
);

-- Table: Voyage Planned Indicators (Измеряемые показатели)
-- Description: Which indicators (parameters) are planned to be measured during a voyage.
-- Acts as a plan or checklist of measurements for each voyage.
CREATE TABLE voyage_indicators (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    voyage_id    UUID NOT NULL,
    indicator_id UUID NOT NULL,
    CONSTRAINT fk_vi_voyage FOREIGN KEY(voyage_id)
        REFERENCES voyages(id) ON DELETE CASCADE,
    CONSTRAINT fk_vi_indicator FOREIGN KEY(indicator_id)
        REFERENCES indicators(id) ON DELETE RESTRICT,
    UNIQUE(voyage_id, indicator_id)
        -- Each indicator is listed at most once per voyage.
);

-- ========================================
-- Measurement Data Table (Consolidated bottom-up)
-- Measurements are recorded on ships and consolidated to the central database (via solver).
-- This table stores individual measured values.
-- ========================================

-- Table: Measurements (Измеренные показатели)
-- Description: Recorded measurement values for various indicators during voyages.
CREATE TABLE measurements (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    voyage_id    UUID NOT NULL,
    indicator_id UUID NOT NULL,    -- the parameter that was measured
    device_id    UUID,            -- device used for measurement (if any)
    method_id    UUID,            -- method used (can be derived from device, or specified for lab measurements)
    unit_id      UUID NOT NULL,   -- unit of the measured value (should match indicator's unit or compatible unit)
    value        NUMERIC NOT NULL,
    measured_at  TIMESTAMP NOT NULL,
    CONSTRAINT fk_measurement_voyage FOREIGN KEY(voyage_id)
        REFERENCES voyages(id) ON DELETE CASCADE,
    CONSTRAINT fk_measurement_indicator FOREIGN KEY(indicator_id)
        REFERENCES indicators(id) ON DELETE RESTRICT,
    CONSTRAINT fk_measurement_device FOREIGN KEY(device_id)
        REFERENCES devices(id) ON DELETE SET NULL,
    CONSTRAINT fk_measurement_method FOREIGN KEY(method_id)
        REFERENCES methods(id) ON DELETE SET NULL,
    CONSTRAINT fk_measurement_unit FOREIGN KEY(unit_id)
        REFERENCES units(id) ON DELETE RESTRICT
        -- If a voyage is deleted, all its measurements are deleted (cascaded).
        -- Devices or methods being removed sets device_id/method_id to NULL for historical data.
);

-- ========================================
-- Audit Logging Table
-- Logs for auditing changes, populated via triggers.
-- Not part of the 14 main tables, but used for logging events.
-- ========================================

-- Table: Logs (for change logging)
CREATE TABLE logs (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    log_time   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    entity     TEXT,      -- e.g., table or object type
    entity_id  UUID,      -- reference to the object changed (if applicable)
    operation  TEXT,      -- e.g., "INSERT", "UPDATE"
    message    TEXT       -- descriptive message of the event
);

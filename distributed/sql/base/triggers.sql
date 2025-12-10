-- Trigger Functions and Triggers for Logging and Validation

-- 1. Validation Trigger for Measurements (before insert/update)
--    Ensures data integrity for new measurements: correct method, device assignment, planned indicator, and value range.
CREATE OR REPLACE FUNCTION fn_validate_measurement()
RETURNS TRIGGER AS $$
DECLARE
    ship_of_voyage UUID;
    expected_count INT;
    method_match UUID;
    ind_min NUMERIC;
    ind_max NUMERIC;
BEGIN
    -- Ensure that either a device or a method is provided (at least one source of measurement)
    IF NEW.device_id IS NULL AND NEW.method_id IS NULL THEN
        RAISE EXCEPTION 'Measurement %: either device_id or method_id must be provided', NEW.id;
    END IF;

    -- If a device is specified but method is not, determine the appropriate method via device type and indicator
    IF NEW.device_id IS NOT NULL THEN
        -- Fetch the matching method for this device type and indicator
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
            RAISE EXCEPTION 'Measurement %: Device % is not capable of measuring indicator %',
                NEW.id, NEW.device_id, NEW.indicator_id;
        END IF;
        -- Set the method_id if not explicitly provided
        IF NEW.method_id IS NULL THEN
            NEW.method_id := method_match;
        ELSE
            -- If method was provided, ensure it matches the device's capability
            IF NEW.method_id <> method_match THEN
                RAISE EXCEPTION 'Measurement %: Provided method % does not match device % for indicator %',
                    NEW.id, NEW.method_id, NEW.device_id, NEW.indicator_id;
            END IF;
        END IF;
    ELSE
        -- If no device, a method must be provided; ensure the method corresponds to the indicator
        SELECT indicator_id INTO method_match FROM methods WHERE id = NEW.method_id;
        IF method_match IS NULL THEN
            RAISE EXCEPTION 'Measurement %: Method % not found', NEW.id, NEW.method_id;
        ELSIF method_match <> NEW.indicator_id THEN
            RAISE EXCEPTION 'Measurement %: Method % is for indicator %, does not match indicator % of measurement',
                NEW.id, NEW.method_id, method_match, NEW.indicator_id;
        END IF;
    END IF;

    -- Verify the device (if any) is currently assigned to the ship performing the voyage
    IF NEW.device_id IS NOT NULL THEN
        SELECT v.ship_id INTO ship_of_voyage FROM voyages v WHERE v.id = NEW.voyage_id;
        IF ship_of_voyage IS NULL THEN
            RAISE EXCEPTION 'Measurement %: Voyage % does not exist', NEW.id, NEW.voyage_id;
        END IF;
        PERFORM 1 FROM ship_equipment se 
            WHERE se.ship_id = ship_of_voyage AND se.device_id = NEW.device_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Measurement %: Device % is not assigned to the ship % for voyage %',
                NEW.id, NEW.device_id, ship_of_voyage, NEW.voyage_id;
        END IF;
    END IF;

    -- Check if the indicator is part of the planned measurements for this voyage (if a plan exists)
    SELECT COUNT(*) INTO expected_count FROM voyage_indicators vi WHERE vi.voyage_id = NEW.voyage_id;
    IF expected_count > 0 THEN
        PERFORM 1 FROM voyage_indicators vi 
         WHERE vi.voyage_id = NEW.voyage_id AND vi.indicator_id = NEW.indicator_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Measurement %: Indicator % was not planned for voyage %',
                NEW.id, NEW.indicator_id, NEW.voyage_id;
        END IF;
    END IF;

    -- Validate the measurement value against normal range (if defined for the indicator)
    SELECT normal_min, normal_max INTO ind_min, ind_max FROM indicators WHERE id = NEW.indicator_id;
    IF ind_min IS NOT NULL AND NEW.value < ind_min THEN
        RAISE EXCEPTION 'Measurement %: Value % is below the minimum % for indicator %',
            NEW.id, NEW.value, ind_min, NEW.indicator_id;
    END IF;
    IF ind_max IS NOT NULL AND NEW.value > ind_max THEN
        RAISE EXCEPTION 'Measurement %: Value % exceeds the maximum % for indicator %',
            NEW.id, NEW.value, ind_max, NEW.indicator_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Validation/Automation Trigger for Voyages (before update)
--    Ensures valid status transitions and auto-populates timestamps on status changes.
CREATE OR REPLACE FUNCTION fn_validate_voyage_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Only act if status is changing
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        -- Enforce allowed state transitions: PLANNED -> ONGOING -> COMPLETED
        IF NOT (
            (OLD.status = 'PLANNED' AND NEW.status = 'ONGOING') OR
            (OLD.status = 'ONGOING' AND NEW.status = 'COMPLETED')
           ) THEN
            RAISE EXCEPTION 'Voyage %: invalid status transition from % to %',
                NEW.id, OLD.status, NEW.status;
        END IF;
        -- If starting the voyage, set actual_departure_date if not already set
        IF NEW.status = 'ONGOING' THEN
            IF NEW.actual_departure_date IS NULL THEN
                NEW.actual_departure_date := CURRENT_TIMESTAMP;
            END IF;
        ELSIF NEW.status = 'COMPLETED' THEN
            -- If completing the voyage, set actual_arrival_date if not set
            IF NEW.actual_arrival_date IS NULL THEN
                NEW.actual_arrival_date := CURRENT_TIMESTAMP;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Logging Trigger for Voyage Creation (after insert)
--    Logs when a new voyage is created.
CREATE OR REPLACE FUNCTION fn_log_voyage_created()
RETURNS TRIGGER AS $$
DECLARE
    ship_name TEXT;
    route_name TEXT;
BEGIN
    SELECT s.name, r.name INTO ship_name, route_name
      FROM ships s, routes r
     WHERE s.id = NEW.ship_id AND r.id = NEW.route_id;
    INSERT INTO logs(entity, entity_id, operation, message)
    VALUES ('voyage', NEW.id, 'INSERT',
            format('Voyage %s created: Ship="%s", Route="%s", Status=%s',
                   NEW.id, ship_name, route_name, NEW.status));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Logging Trigger for Voyage Status Change (after update of status)
--    Logs changes in voyage status.
CREATE OR REPLACE FUNCTION fn_log_voyage_status_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO logs(entity, entity_id, operation, message)
    VALUES ('voyage', NEW.id, 'UPDATE',
            format('Voyage %s status changed from %s to %s',
                   NEW.id, OLD.status, NEW.status));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach triggers to tables:

-- Attach measurement validation trigger (before insert or update on measurements)
CREATE TRIGGER trg_measurement_validate
BEFORE INSERT OR UPDATE ON measurements
FOR EACH ROW
EXECUTE PROCEDURE fn_validate_measurement();

-- Attach voyage status validation trigger (before update on voyages)
CREATE TRIGGER trg_voyage_status_validate
BEFORE UPDATE ON voyages
FOR EACH ROW
EXECUTE PROCEDURE fn_validate_voyage_status();

-- Attach logging trigger for voyage insert
CREATE TRIGGER trg_voyage_log_create
AFTER INSERT ON voyages
FOR EACH ROW
EXECUTE PROCEDURE fn_log_voyage_created();

-- Attach logging trigger for voyage status updates (only when status changes)
CREATE TRIGGER trg_voyage_log_status
AFTER UPDATE OF status ON voyages
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE PROCEDURE fn_log_voyage_status_change();

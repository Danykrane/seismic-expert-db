-- Migration Script: Adjust schema for a new "pickup" flow scenario.
-- Scenario: Introducing a new intermediate status where voyage data is awaiting pickup at port before final completion.

-- 1. Add new status value to voyage_status type for "AWAITING_PICKUP"
ALTER TYPE voyage_status ADD VALUE IF NOT EXISTS 'AWAITING_PICKUP' AFTER 'ONGOING';

-- 2. Update voyage status validation trigger to allow new transition ONGOING -> AWAITING_PICKUP -> COMPLETED.
DROP TRIGGER IF EXISTS trg_voyage_status_validate ON voyages;
CREATE TRIGGER trg_voyage_status_validate
BEFORE UPDATE ON voyages
FOR EACH ROW
EXECUTE PROCEDURE fn_validate_voyage_status();
-- (The function fn_validate_voyage_status should be updated accordingly to permit AWAITING_PICKUP transitions, 
-- or the logic can be adjusted in a new function.)
-- For simplicity in this migration, assume manual update of trigger function to handle new status transitions.

-- 3. (Optional) Add a column to voyages to track when data pickup occurred.
ALTER TABLE voyages ADD COLUMN data_picked_up_at TIMESTAMP;
-- This can store the timestamp when measurement data was collected/picked up from the ship at port.

-- 4. (Optional) If needed, update views to account for the new status (e.g., treat AWAITING_PICKUP as incomplete in reports).
-- No changes required in existing views for basic functionality.

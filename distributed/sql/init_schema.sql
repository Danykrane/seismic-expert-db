-- Initialization script: create schema and objects, then optionally seed data.
\i base/extensions.sql;
\i base/schema.sql;
\i base/triggers.sql;
\i base/views.sql;

-- Note: Run seed_data.sql separately to populate reference and demo data, as needed.
-- \i seed_data.sql;

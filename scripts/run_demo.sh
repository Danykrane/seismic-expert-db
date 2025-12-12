#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE=${COMPOSE_FILE:-docker-compose.yml}
CENTER_CONT=${CENTER_CONT:-pg-center}
PORTS_CONT=${PORTS_CONT:-pg-ports}
SHIPS_CONT=${SHIPS_CONT:-pg-ships}
SOLVER_CONT=${SOLVER_CONT:-pg-solver}
DB_NAME=${DB_NAME:-marine_db}
DB_USER=${DB_USER:-app}
DB_PASS=${DB_PASS:-app_password}

# Publication/subscription names
PUB_NSI=${PUB_NSI:-pub_nsi}  # Reference data (НСИ)
PUB_PLAN=${PUB_PLAN:-pub_plan}  # Planning data (routes, voyages, voyage_indicators)
PUB_MEASUREMENTS=${PUB_MEASUREMENTS:-pub_measurements}  # Measurement data from ships

# Subscriptions
SUB_NSI=${SUB_NSI:-sub_nsi}
SUB_PLAN=${SUB_PLAN:-sub_plan}
SUB_MEASUREMENTS=${SUB_MEASUREMENTS:-sub_measurements}

hr(){ printf "\n%s\n" "────────────────────────────────────────────────────"; }
title(){ printf "\n== %s ==\n" "$1"; }
sub_caught_up(){ local n=$1; psql_ports "SELECT (received_lsn = latest_end_lsn) FROM pg_stat_subscription WHERE subname='${n}';" | tr -d ' '; }

wait_healthy(){ local c=$1; for i in {1..60}; do s=$(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null || true); [[ "$s" == healthy ]] && return 0; sleep 1; done; return 1; }

psql_center(){ docker exec -i "$CENTER_CONT" env PGPASSWORD="$DB_PASS" psql -X -q -t -A -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='CENTER'; $1"; }
psql_center_cmd(){ docker exec -i "$CENTER_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='CENTER'; $1"; }
psql_center_file(){ docker exec -i "$CENTER_CONT" env PGPASSWORD="$DB_PASS" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='CENTER';" -f "$1"; }

psql_ports(){ docker exec -i "$PORTS_CONT" env PGPASSWORD="$DB_PASS" psql -X -q -t -A -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='PORTS'; $1"; }
psql_ports_cmd(){ docker exec -i "$PORTS_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='PORTS'; $1"; }
psql_ports_file(){ docker exec -i "$PORTS_CONT" env PGPASSWORD="$DB_PASS" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='PORTS';" -f "$1"; }

psql_ships(){ docker exec -i "$SHIPS_CONT" env PGPASSWORD="$DB_PASS" psql -X -q -t -A -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='SHIPS'; $1"; }
psql_ships_cmd(){ docker exec -i "$SHIPS_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='SHIPS'; $1"; }
psql_ships_file(){ docker exec -i "$SHIPS_CONT" env PGPASSWORD="$DB_PASS" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='SHIPS';" -f "$1"; }

psql_solver(){ docker exec -i "$SOLVER_CONT" env PGPASSWORD="$DB_PASS" psql -X -q -t -A -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='SOLVER'; $1"; }
psql_solver_cmd(){ docker exec -i "$SOLVER_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='SOLVER'; $1"; }
psql_solver_file(){ docker exec -i "$SOLVER_CONT" env PGPASSWORD="$DB_PASS" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "SET application_name='SOLVER';" -f "$1"; }

# Raw command without application name setting (for system operations)
psql_center_cmd_raw(){ docker exec -i "$CENTER_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$1"; }
psql_ports_cmd_raw(){ docker exec -i "$PORTS_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$1"; }
psql_ships_cmd_raw(){ docker exec -i "$SHIPS_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$1"; }
psql_solver_cmd_raw(){ docker exec -i "$SOLVER_CONT" env PGPASSWORD="$DB_PASS" psql -X -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$1"; }

title "Reset docker compose"
docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
docker compose -f "$COMPOSE_FILE" up -d
wait_healthy "$CENTER_CONT" && wait_healthy "$PORTS_CONT" && wait_healthy "$SHIPS_CONT" && wait_healthy "$SOLVER_CONT"

title "Init CENTER (Control Center)"
psql_center_file "/sql/full/all_tables_and_indexes.sql"
psql_center_file "/sql/full/insert_data.sql"

title "Init PORTS (Ports Node)"
psql_ports_file "/sql/full/all_tables_and_indexes.sql"

title "Init SHIPS (Ships Node)"
psql_ships_file "/sql/full/all_tables_and_indexes.sql"

title "Init SOLVER (Solver Node)"
psql_solver_file "/sql/full/all_tables_and_indexes.sql"

title "Setting up Publications and Subscriptions"

# 1. NSI (Reference Data) from CENTER to PORTS and SHIPS
psql_center_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_NSI}') THEN CREATE PUBLICATION ${PUB_NSI} FOR TABLE aquatories, ports, units, indicators, device_types, methods, method_usage, devices, ships, ship_equipment; END IF; END\$\$;"

psql_ports_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${SUB_NSI}_to_ports;"
psql_ports_cmd_raw "CREATE SUBSCRIPTION ${SUB_NSI}_to_ports CONNECTION 'host=pg-center port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=PORTS_NSI' PUBLICATION ${PUB_NSI} WITH (copy_data = true);"

# Also subscribe SHIPS to relevant NSI (limited subset needed for their operations)
psql_ships_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${SUB_NSI}_to_ships;"
psql_ships_cmd_raw "CREATE SUBSCRIPTION ${SUB_NSI}_to_ships CONNECTION 'host=pg-center port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=SHIPS_NSI' PUBLICATION ${PUB_NSI} WITH (copy_data = true);"

# 2. Planning data (routes, voyages, voyage_indicators) - bidirectional between CENTER and PORTS
psql_center_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_PLAN}') THEN CREATE PUBLICATION ${PUB_PLAN} FOR TABLE routes, voyages, voyage_indicators; END IF; END\$\$;"

psql_ports_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_PLAN}') THEN CREATE PUBLICATION ${PUB_PLAN} FOR TABLE routes, voyages, voyage_indicators; END IF; END\$\$;"

psql_center_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${SUB_PLAN};"
psql_center_cmd_raw "CREATE SUBSCRIPTION ${SUB_PLAN} CONNECTION 'host=pg-ports port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=CENTER_PLAN' PUBLICATION ${PUB_PLAN} WITH (copy_data = false);"

psql_ports_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${SUB_PLAN}_center;"
psql_ports_cmd_raw "CREATE SUBSCRIPTION ${SUB_PLAN}_center CONNECTION 'host=pg-center port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=PORTS_PLAN' PUBLICATION ${PUB_PLAN} WITH (copy_data = true);"

# 3. Measurement data - from SHIPS to SOLVER
psql_ships_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_MEASUREMENTS}') THEN CREATE PUBLICATION ${PUB_MEASUREMENTS} FOR TABLE measurements; END IF; END\$\$;"

psql_solver_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${SUB_MEASUREMENTS};"
psql_solver_cmd_raw "CREATE SUBSCRIPTION ${SUB_MEASUREMENTS} CONNECTION 'host=pg-ships port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=SOLVER_MEASUREMENTS' PUBLICATION ${PUB_MEASUREMENTS} WITH (copy_data = false);"

title "Waiting for data synchronization..."

# Wait for NSI to sync to PORTS
for i in {1..60}; do
  [[ "$(sub_caught_up ${SUB_NSI})" == "t" ]] && break || sleep 1
done

title "Seismic Expert DB 4-node setup completed successfully!"
echo "Nodes:"
echo "  - CENTER (Control Center): localhost:5432 (application_name='CENTER')"
echo "  - PORTS (Ports Node): localhost:5433 (application_name='PORTS')"
echo "  - SHIPS (Ships Node): localhost:5434 (application_name='SHIPS')"
echo "  - SOLVER (Solver Node): localhost:5435 (application_name='SOLVER')"
echo ""
echo "Publications:"
echo "  - CENTER: ${PUB_NSI} (NSI data), ${PUB_PLAN} (planning data)"
echo "  - PORTS: ${PUB_PLAN} (planning data)"
echo "  - SHIPS: ${PUB_MEASUREMENTS} (measurements)"
echo ""
echo "Subscriptions:"
echo "  - PORTS: ${SUB_NSI} (NSI data from CENTER), ${SUB_PLAN}_center (planning from CENTER)"
echo "  - CENTER: ${SUB_PLAN} (planning data from PORTS)"
echo "  - SHIPS: ${SUB_NSI} (NSI data from CENTER)"
echo "  - SOLVER: ${SUB_MEASUREMENTS} (measurements from SHIPS)"
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

hr
echo "РАСПРЕДЕЛЕННАЯ БД МОРСКИХ ИССЛЕДОВАНИЙ - ДЕМОНСТРАЦИОННЫЙ СКРИПТ"
echo "Архитектура: Control Center ↔ Ports ↔ Ships ↔ Solver"
hr

title "СБРОС СИСТЕМЫ"
docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
docker compose -f "$COMPOSE_FILE" up -d
wait_healthy "$CENTER_CONT" && wait_healthy "$PORTS_CONT" && wait_healthy "$SHIPS_CONT" && wait_healthy "$SOLVER_CONT"

title "ИНИЦИАЛИЗАЦИЯ УЗЛОВ"

echo "1. Инициализация ЦЕНТРАЛЬНОГО узла (Control Center)"
echo "   - PRIMARY для справочников (НСИ): aquatories, ports, ships, devices, indicators..."
echo "   - PRIMARY для планирования: routes, voyages, voyage_indicators"
psql_center_file "/sql/full/all_tables_and_indexes.sql"
psql_center_file "/sql/full/insert_data.sql"

echo "2. Инициализация узла ПОРТОВ (Ports Node)"
echo "   - RO-копии справочников из Центра"
echo "   - RW для локального планирования рейсов"
psql_ports_file "/sql/full/all_tables_and_indexes.sql"

echo "3. Инициализация узла СУДОВ (Ships Node)"
echo "   - RO-копии справочников, относящихся к конкретному судну"
echo "   - PRIMARY для измерений measurements (режим оффлайн)"
psql_ships_file "/sql/full/all_tables_and_indexes.sql"

echo "4. Инициализация узла СОЛВЕРА (Solver Node)"
echo "   - PRIMARY для консолидированной таблицы measurements"
echo "   - Аналитические представления: top10_nitrate_locations, expedition_report..."
psql_solver_file "/sql/full/all_tables_and_indexes.sql"

title "НАСТРОЙКА ЛОГИЧЕСКОЙ РЕПЛИКАЦИИ"

echo "1. РЕПЛИКАЦИЯ СПРАВОЧНЫХ ДАННЫХ (NSI):"
echo "   - Публикация NSI данных на ЦЕНТРЕ -> Репликация на ПОРТЫ и СУДА"
psql_center_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_NSI}') THEN CREATE PUBLICATION ${PUB_NSI} FOR TABLE aquatories, ports, units, indicators, device_types, methods, method_usage, devices, ships, ship_equipment; END IF; END\$\$;"

psql_ports_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${PUB_NSI}_to_ports;"
psql_ports_cmd_raw "CREATE SUBSCRIPTION ${PUB_NSI}_to_ports CONNECTION 'host=pg-center port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=PORTS_NSI' PUBLICATION ${PUB_NSI} WITH (copy_data = true);"
echo "   -> Подписка ПОРТОВ на NSI данные ЦЕНТРА"

psql_ships_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${PUB_NSI}_to_ships;"
psql_ships_cmd_raw "CREATE SUBSCRIPTION ${PUB_NSI}_to_ships CONNECTION 'host=pg-center port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=SHIPS_NSI' PUBLICATION ${PUB_NSI} WITH (copy_data = true);"
echo "   -> Подписка СУДОВ на NSI данные ЦЕНТРА"

echo ""
echo "2. ДВУНАПРАВЛЕННАЯ РЕПЛИКАЦИЯ ПЛАНИРОВАНИЯ:"
echo "   - Планирование между ЦЕНТРОМ и ПОРТАМИ"
psql_center_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_PLAN}') THEN CREATE PUBLICATION ${PUB_PLAN} FOR TABLE routes, voyages, voyage_indicators; END IF; END\$\$;"

psql_ports_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_PLAN}') THEN CREATE PUBLICATION ${PUB_PLAN} FOR TABLE routes, voyages, voyage_indicators; END IF; END\$\$;"

psql_center_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${PUB_PLAN}_to_center;"
psql_center_cmd_raw "CREATE SUBSCRIPTION ${PUB_PLAN}_to_center CONNECTION 'host=pg-ports port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=CENTER_PLAN' PUBLICATION ${PUB_PLAN} WITH (copy_data = false);"
echo "   -> Подписка ЦЕНТРА на планирование от ПОРТОВ"

psql_ports_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${PUB_PLAN}_to_ports;"
psql_ports_cmd_raw "CREATE SUBSCRIPTION ${PUB_PLAN}_to_ports CONNECTION 'host=pg-center port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=PORTS_PLAN' PUBLICATION ${PUB_PLAN} WITH (copy_data = true);"
echo "   -> Подписка ПОРТОВ на планирование от ЦЕНТРА"

echo ""
echo "3. РЕПЛИКАЦИЯ ИЗМЕРЕНИЙ (MEASUREMENTS):"
echo "   - Консолидация измерений от СУДОВ к СОЛВЕРУ"
psql_ships_cmd "DO \$\$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='${PUB_MEASUREMENTS}') THEN CREATE PUBLICATION ${PUB_MEASUREMENTS} FOR TABLE measurements; END IF; END\$\$;"

psql_solver_cmd_raw "DROP SUBSCRIPTION IF EXISTS ${PUB_MEASUREMENTS}_to_solver;"
psql_solver_cmd_raw "CREATE SUBSCRIPTION ${PUB_MEASUREMENTS}_to_solver CONNECTION 'host=pg-ships port=5432 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS} application_name=SOLVER_MEASUREMENTS' PUBLICATION ${PUB_MEASUREMENTS} WITH (copy_data = false);"
echo "   -> Подписка СОЛВЕРА на измерения от СУДОВ"

title "ПРОВЕРКА СОСТОЯНИЯ РЕПЛИКАЦИИ"

echo "Проверка репликационных слотов на ЦЕНТРЕ:"
echo "$(psql_center_cmd_raw "SELECT slot_name, active FROM pg_replication_slots;")"

echo ""
echo "Проверка публикаций на ПОРТАХ:"
echo "$(psql_ports_cmd_raw "SELECT pubname FROM pg_publication;")"

echo ""
echo "Проверка публикаций на СУДАХ:"
echo "$(psql_ships_cmd_raw "SELECT pubname FROM pg_publication;")"

echo ""
echo "Проверка подписок на СОЛВЕРЕ:"
echo "$(psql_solver_cmd_raw "SELECT subname, subenabled FROM pg_subscription;")"

title "ПРОВЕРКА ДАННЫХ НА КАЖДОМ УЗЛЕ"

echo "Данные на ЦЕНТРАЛЬНОМ узле:"
echo "  - Суда: $(psql_center_cmd_raw "SELECT COUNT(*) FROM ships;")"
echo "  - Акватории: $(psql_center_cmd_raw "SELECT COUNT(*) FROM aquatories;")" 
echo "  - Рейсы: $(psql_center_cmd_raw "SELECT COUNT(*) FROM voyages;")"
echo "  - Измерения: $(psql_center_cmd_raw "SELECT COUNT(*) FROM measurements;")"

echo ""
echo "Данные на узле ПОРТОВ:"
echo "  - Суда: $(psql_ports_cmd_raw "SELECT COUNT(*) FROM ships;")"
echo "  - Акватории: $(psql_ports_cmd_raw "SELECT COUNT(*) FROM aquatories;")"
echo "  - Рейсы: $(psql_ports_cmd_raw "SELECT COUNT(*) FROM voyages;")"
echo "  - Измерения: $(psql_ports_cmd_raw "SELECT COUNT(*) FROM measurements;")"

echo ""
echo "Данные на узле СУДОВ:"
echo "  - Суда: $(psql_ships_cmd_raw "SELECT COUNT(*) FROM ships;")"
echo "  - Акватории: $(psql_ships_cmd_raw "SELECT COUNT(*) FROM aquatories;")"
echo "  - Рейсы: $(psql_ships_cmd_raw "SELECT COUNT(*) FROM voyages;")"
echo "  - Измерения: $(psql_ships_cmd_raw "SELECT COUNT(*) FROM measurements;")"

echo ""
echo "Данные на узле СОЛВЕРА:"
echo "  - Суда: $(psql_solver_cmd_raw "SELECT COUNT(*) FROM ships;")"
echo "  - Акватории: $(psql_solver_cmd_raw "SELECT COUNT(*) FROM aquatories;")"
echo "  - Рейсы: $(psql_solver_cmd_raw "SELECT COUNT(*) FROM voyages;")"
echo "  - Измерения: $(psql_solver_cmd_raw "SELECT COUNT(*) FROM measurements;")"

title "ПРОВЕРКА АНАЛИТИЧЕСКИХ ПРЕДСТАВЛЕНИЙ (на Солвере)"

echo "Топ-10 локаций по среднему нитрату:"
echo "$(psql_solver_cmd_raw "SELECT * FROM top10_nitrate_locations LIMIT 3;")"

echo ""
echo "Отчет по экспедициям (рейсам):"
echo "$(psql_solver_cmd_raw "SELECT * FROM expedition_report LIMIT 3;")"

hr
echo "РЕПЛИКАЦИОННЫЙ ПЛАН:"
echo "┌─────────────┐    NSI    ┌──────────┐"
echo "│   ЦЕНТР     │ ────────► │   ПОРТЫ  │"
echo "│ (Primary)   │           │(Read-Only)│"
echo "└─────────────┘           └──────────┘"
echo "       │                        │"
echo "       │ NSI                    │ Двунаправленная"
echo "       │                        │ репликация"
echo "       ▼                        ▼"
echo "┌─────────────┐    NSI    ┌──────────┐"
echo "│    СУДА     │ ────────► │ СОЛВЕР   │"
echo "│(Read-Only)  │           │(Primary) │"
echo "└─────────────┘           └──────────┘"
echo "       │                        │"
echo "       │ Измерения              │"
echo "       └────────────────────────┘"

hr
echo "АРХИТЕКТУРА:"
echo "- Узел Центра: PRIMARY для справочников и централизованного планирования"
echo "- Узел Портов: RO-доступ к справочникам, RW-доступ к местному планированию"
echo "- Узел Судов: RO-доступ к справочникам, PRIMARY для измерений (оффлайн режим)"
echo "- Узел Солвера: PRIMARY для консолидации измерений и аналитики"

hr
echo "СИСТЕМА ГОТОВА К РАБОТЕ!"
echo "Для подключения к узлам используйте:"
echo "  - Центр: psql -h localhost -p 5432 -U app -d marine_db"
echo "  - Порты: psql -h localhost -p 5433 -U app -d marine_db"
echo "  - Суда:  psql -h localhost -p 5434 -U app -d marine_db"
echo "  - Солвер: psql -h localhost -p 5435 -U app -d marine_db"
hr
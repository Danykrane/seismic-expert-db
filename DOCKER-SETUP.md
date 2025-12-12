# Распределённая БД морских измерений (Control Center ↔ Ports ↔ Ships ↔ Solver) - Демо

## Быстрый старт

Для запуска демонстрационного стенда с 4 узлами выполните:

```bash
bash scripts/run_demo.sh
```

Скрипт автоматически:
1. Запускает 4 контейнера PostgreSQL (Control Center, Ports, Ships, Solver)
2. Инициализирует схемы данных на каждом узле
3. Настраивает логическую репликацию между узлами
4. Загружает тестовые данные

## Архитектура

### Узлы

1. **Control Center (localhost:5432)**
   - PRIMARY для справочников (НСИ): `aquatories`, `ports`, `ships`, `device_types`, `devices`, `ship_equipment`, `units`, `indicators`, `methods`, `method_usage`
   - PRIMARY/MASTER для планирования: `routes`, `voyages`, `voyage_indicators`

2. **Ports (localhost:5433)**
   - RO-копии справочников из Control Center
   - READ/WRITE для локального планирования рейсов
   - Двусторонняя репликация планирования с Control Center

3. **Ships (localhost:5434)**
   - RO-выборка справочников, относящихся к конкретному судну
   - PRIMARY для измерений `measurements`
   - Репликация измерений в Solver

4. **Solver (localhost:5435)**
   - PRIMARY для консолидированной таблицы `measurements` 
   - Аналитические представления: `top10_nitrate_locations`, `expedition_report`, `avg_param_values_by_month`, `ship_report`

### Репликация

- **NSI (Номенклатура справочной информации)**: Control Center → Ports, Ships
- **Планирование**: Двусторонняя репликация между Control Center ↔ Ports
- **Измерения**: Ships → Solver (консолидация данных)

## Подключение к узлам

После запуска скрипта можно подключаться к каждому узлу:

```bash
# Control Center
psql -h localhost -p 5432 -U app -d marine_db

# Ports
psql -h localhost -p 5433 -U app -d marine_db

# Ships  
psql -h localhost -p 5434 -U app -d marine_db

# Solver
psql -h localhost -p 5435 -U app -d marine_db
```

## Проверка работы

После запуска демо-скрипта можно проверить работу представлений на Solver узле:

```sql
-- Подключитесь к Solver узлу (localhost:5435)
SELECT * FROM top10_nitrate_locations;
SELECT * FROM expedition_report;
SELECT * FROM avg_param_values_by_month;
SELECT * FROM ship_report;
```

## Диагностика репликации

Для проверки состояния репликации на любом узле:

```sql
SELECT subname, received_lsn, latest_end_lsn, latest_end_time FROM pg_stat_subscription;
```

## Сброс стенда

Для полного сброса стенда просто запустите скрипт заново:

```bash
bash scripts/run_demo.sh
```

Скрипт автоматически остановит и удалит все контейнеры, затем создаст новую инсталляцию.
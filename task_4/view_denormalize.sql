-- =============================================================================
-- Задание 4. ClickHouse: View и денормализованная таблица
-- =============================================================================
-- База данных: default
-- =============================================================================

CREATE DATABASE IF NOT EXISTS default;

-- 1. Представление (VIEW) в схеме default, восстанавливающее 12 колонок из PostgreSQL
CREATE OR REPLACE VIEW default.v_test_dataset_denormalized AS
SELECT
    l.uuid                                                  AS uuid,
    l.object_id                                             AS object_id,
    coalesce(cx.name, 'не указан')                          AS complex_name,
    coalesce(d.name, 'не указан')                           AS developer_name,
    l.price                                                 AS price,
    l.square                                                AS square,
    cx.lat                                                  AS lat,
    cx.lon                                                  AS lon,
    wt.name                                                 AS wall_type,
    toDateTime(l.load_date)                                 AS load_date,
    coalesce(c.code, 'не указан')                           AS city,
    ds.name                                                 AS data_source
FROM postgresql('postgres:5432', 'airflow', 'listing', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization') AS l
LEFT JOIN postgresql('postgres:5432', 'airflow', 'object', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization') AS o
    ON l.object_id = o.object_id
LEFT JOIN postgresql('postgres:5432', 'airflow', 'complex', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization') AS cx
    ON o.complex_id = cx.complex_id
LEFT JOIN postgresql('postgres:5432', 'airflow', 'developer', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization') AS d
    ON cx.developer_id = d.developer_id
LEFT JOIN postgresql('postgres:5432', 'airflow', 'city', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization') AS c
    ON cx.city_id = c.city_id
JOIN postgresql('postgres:5432', 'airflow', 'wall_type', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization') AS wt
    ON l.wall_type_id = wt.wall_type_id
JOIN postgresql('postgres:5432', 'airflow', 'data_source', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization') AS ds
    ON l.data_source_id = ds.data_source_id;

-- 2. Физическая денормализованная таблица на основе VIEW в схеме default
CREATE TABLE IF NOT EXISTS default.test_dataset_denormalized
ENGINE = MergeTree()
ORDER BY (city, load_date, uuid)
AS SELECT * FROM default.v_test_dataset_denormalized;

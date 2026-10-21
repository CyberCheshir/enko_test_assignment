-- =============================================================================
-- Задание 4. ClickHouse: View, подключающийся к PostgreSQL и денормализующий 3НФ
-- =============================================================================

-- 1. Подключение ClickHouse к схеме normalization в PostgreSQL
CREATE DATABASE IF NOT EXISTS pg_normalization
ENGINE = PostgreSQL('postgres:5432', 'airflow', 'airflow', '_-oW0TRj8GM2B-QHTqgMxHkrpkhg3kDw', 'normalization');

-- 2. Создание представления (VIEW), которое на лету денормализует данные из PostgreSQL
--    к 12 колонкам исходного test_dataset.csv
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
    l.load_date                                             AS load_date,
    coalesce(c.code, 'не указан')                           AS city,
    ds.name                                                 AS data_source
FROM pg_normalization.listing AS l
LEFT JOIN pg_normalization.object AS o
    ON l.object_id = o.object_id
LEFT JOIN pg_normalization.complex AS cx
    ON o.complex_id = cx.complex_id
LEFT JOIN pg_normalization.developer AS d
    ON cx.developer_id = d.developer_id
LEFT JOIN pg_normalization.city AS c
    ON cx.city_id = c.city_id
JOIN pg_normalization.wall_type AS wt
    ON l.wall_type_id = wt.wall_type_id
JOIN pg_normalization.data_source AS ds
    ON l.data_source_id = ds.data_source_id;

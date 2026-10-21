-- =============================================================================
-- Задание 3. Нормализация данных raw.test_dataset в 3НФ
-- =============================================================================
-- Единый скрипт:
--   1. Создает схему normalization и таблицы 3НФ с первичными и внешними ключами.
--   2. Раскладывает данные из raw.test_dataset по сущностям и справочникам.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- ЧАСТЬ 1. DDL: Создание схемы и таблиц 3НФ
-- -----------------------------------------------------------------------------

DROP SCHEMA IF EXISTS normalization CASCADE;
CREATE SCHEMA normalization;

-- 1.1. Справочники
CREATE TABLE normalization.wall_type (
    wall_type_id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name           TEXT NOT NULL,
    CONSTRAINT wall_type_name_uniq UNIQUE (name)
);

CREATE TABLE normalization.developer (
    developer_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name           TEXT NOT NULL,
    CONSTRAINT developer_name_uniq UNIQUE (name)
);

CREATE TABLE normalization.city (
    city_id        SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code           TEXT NOT NULL,
    CONSTRAINT city_code_uniq UNIQUE (code)
);

CREATE TABLE normalization.data_source (
    data_source_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name           TEXT NOT NULL,
    CONSTRAINT data_source_name_uniq UNIQUE (name)
);

-- 1.2. Сущность: Жилой комплекс
CREATE TABLE normalization.complex (
    complex_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name           TEXT NOT NULL,
    developer_id   INTEGER  NOT NULL REFERENCES normalization.developer (developer_id),
    city_id        SMALLINT NOT NULL REFERENCES normalization.city (city_id),
    lat            DOUBLE PRECISION,
    lon            DOUBLE PRECISION,
    CONSTRAINT complex_natural_key UNIQUE (name, developer_id, city_id)
);

-- 1.3. Сущность: Объект недвижимости
CREATE TABLE normalization.object (
    object_id      BIGINT  NOT NULL PRIMARY KEY,
    complex_id     INTEGER NOT NULL REFERENCES normalization.complex (complex_id)
);

-- 1.4. Факт: Предложение (Листинг)
CREATE TABLE normalization.listing (
    uuid           UUID             NOT NULL PRIMARY KEY,
    object_id      BIGINT           REFERENCES normalization.object (object_id),
    wall_type_id   SMALLINT         NOT NULL REFERENCES normalization.wall_type (wall_type_id),
    data_source_id SMALLINT         NOT NULL REFERENCES normalization.data_source (data_source_id),
    price          NUMERIC(15, 2)   NOT NULL,
    square         NUMERIC(10, 2)   NOT NULL,
    load_date      TIMESTAMP        NOT NULL
);

-- Индексы для внешних ключей и частых фильтров
CREATE INDEX listing_object_id_idx      ON normalization.listing (object_id);
CREATE INDEX listing_wall_type_id_idx   ON normalization.listing (wall_type_id);
CREATE INDEX listing_data_source_id_idx ON normalization.listing (data_source_id);
CREATE INDEX listing_load_date_idx      ON normalization.listing (load_date);


-- -----------------------------------------------------------------------------
-- ЧАСТЬ 2. DML: Заполнение таблиц из raw.test_dataset
-- -----------------------------------------------------------------------------

-- 2.1. Подготовка уникальных ЖК с сохранением координат
CREATE TEMP TABLE _complex_coords ON COMMIT DROP AS
SELECT DISTINCT ON (COALESCE(NULLIF(btrim(complex_name), ''), 'не указан'),
                    COALESCE(NULLIF(btrim(developer_name), ''), 'не указан'),
                    COALESCE(NULLIF(btrim(city), ''), 'не указан'))
       COALESCE(NULLIF(btrim(complex_name), ''), 'не указан') AS complex_name,
       COALESCE(NULLIF(btrim(developer_name), ''), 'не указан') AS developer_name,
       COALESCE(NULLIF(btrim(city), ''), 'не указан') AS city,
       lat,
       lon
FROM raw.test_dataset
ORDER BY 1, 2, 3, 4, 5;

CREATE INDEX ON _complex_coords (complex_name, developer_name, city);

-- 2.2. Наполнение справочников
-- Типы стен
INSERT INTO normalization.wall_type (wall_type_id, name)
OVERRIDING SYSTEM VALUE
SELECT 0, 'не указан';

INSERT INTO normalization.wall_type (name)
SELECT DISTINCT btrim(wall_type)
FROM raw.test_dataset
WHERE wall_type IS NOT NULL AND btrim(wall_type) <> ''
ORDER BY 1;

-- Застройщики
INSERT INTO normalization.developer (developer_id, name)
OVERRIDING SYSTEM VALUE
SELECT 0, 'не указан';

INSERT INTO normalization.developer (name)
SELECT DISTINCT btrim(developer_name)
FROM raw.test_dataset
WHERE developer_name IS NOT NULL AND btrim(developer_name) <> ''
ORDER BY 1;

-- Города
INSERT INTO normalization.city (city_id, code)
OVERRIDING SYSTEM VALUE
SELECT 0, 'не указан';

INSERT INTO normalization.city (code)
SELECT DISTINCT btrim(city)
FROM raw.test_dataset
WHERE city IS NOT NULL AND btrim(city) <> ''
ORDER BY 1;

-- Источники данных
INSERT INTO normalization.data_source (data_source_id, name)
OVERRIDING SYSTEM VALUE
SELECT 0, 'не указан';

INSERT INTO normalization.data_source (name)
SELECT DISTINCT btrim(data_source)
FROM raw.test_dataset
WHERE data_source IS NOT NULL AND btrim(data_source) <> ''
ORDER BY 1;

-- 2.3. Наполнение ЖК
INSERT INTO normalization.complex (name, developer_id, city_id, lat, lon)
SELECT
    cc.complex_name,
    d.developer_id,
    c.city_id,
    cc.lat,
    cc.lon
FROM _complex_coords cc
JOIN normalization.developer d ON d.name = cc.developer_name
JOIN normalization.city c      ON c.code = cc.city;

-- 2.4. Наполнение объектов недвижимости
CREATE TEMP TABLE _complex_id_map ON COMMIT DROP AS
SELECT cc.complex_name, cc.developer_name, cc.city, cx.complex_id
FROM _complex_coords cc
JOIN normalization.developer d ON d.name = cc.developer_name
JOIN normalization.city c      ON c.code = cc.city
JOIN normalization.complex cx
  ON cx.name = cc.complex_name
 AND cx.developer_id = d.developer_id
 AND cx.city_id = c.city_id;

CREATE INDEX ON _complex_id_map (complex_name, developer_name, city);

-- Реальные объекты (без заглушек, только те, у которых есть object_id)
INSERT INTO normalization.object (object_id, complex_id)
SELECT DISTINCT r.object_id, m.complex_id
FROM raw.test_dataset r
JOIN _complex_id_map m
  ON m.complex_name   = COALESCE(NULLIF(btrim(r.complex_name), ''), 'не указан')
 AND m.developer_name = COALESCE(NULLIF(btrim(r.developer_name), ''), 'не указан')
 AND m.city           = COALESCE(NULLIF(btrim(r.city), ''), 'не указан')
WHERE r.object_id IS NOT NULL;

-- 2.5. Наполнение фактов (Листинги)
INSERT INTO normalization.listing (
    uuid,
    object_id,
    wall_type_id,
    data_source_id,
    price,
    square,
    load_date
)
SELECT
    r.uuid::UUID,
    r.object_id,
    wt.wall_type_id,
    ds.data_source_id,
    r.price,
    r.square,
    r.load_date
FROM raw.test_dataset r
JOIN normalization.wall_type wt
  ON wt.name = COALESCE(NULLIF(btrim(r.wall_type), ''), 'не указан')
JOIN normalization.data_source ds
  ON ds.name = COALESCE(NULLIF(btrim(r.data_source), ''), 'не указан');

COMMIT;

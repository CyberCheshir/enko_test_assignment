from __future__ import annotations

import csv
import logging
import os
import tempfile
from datetime import datetime

from airflow.sdk import dag, task
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.postgres.hooks.postgres import PostgresHook

logger = logging.getLogger(__name__)

S3_CONN_ID = "rustfs_default"
PG_CONN_ID = "warehouse_postgres"

S3_BUCKET = os.getenv("S3_BUCKET", "test-dataset")
S3_KEY = os.getenv("S3_KEY", "preprocessed.csv")

CSV_DELIMITER = "|"
SCHEMA = "raw"
TABLE = "test_dataset"


COLUMNS = [
    ("uuid", "TEXT NOT NULL"),
    ("object_id", "BIGINT"),
    ("complex_name", "TEXT"),
    ("developer_name", "TEXT"),
    ("price", "NUMERIC(15, 2)"),
    ("square", "NUMERIC(10, 2)"),
    ("lat", "DOUBLE PRECISION"),
    ("lon", "DOUBLE PRECISION"),
    ("wall_type", "TEXT"),
    ("load_date", "TIMESTAMP"),
    ("city", "TEXT"),
    ("data_source", "TEXT"),
]
COLUMN_NAMES = ", ".join(name for name, _ in COLUMNS)
CREATE_TABLE_SQL = (
    f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}; "
    f"CREATE TABLE IF NOT EXISTS {SCHEMA}.{TABLE} ("
    + ", ".join(f"{name} {sql_type}" for name, sql_type in COLUMNS)
    + ");"
)
COPY_SQL = (
    f"COPY {SCHEMA}.{TABLE} ({COLUMN_NAMES}) "
    f"FROM STDIN WITH (FORMAT csv, DELIMITER '{CSV_DELIMITER}', HEADER true, "
    f"QUOTE '\"', ENCODING 'UTF8')"
)


@dag(
    dag_id="test_dataset_s3_to_postgres",
    description="Load preprocessed.csv from S3 (RustFS) into PostgreSQL 1:1",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": 30},
    tags=["test-task", "s3", "postgres"],
)
def s3_to_postgres_pipeline():
    """ELT загрузки исходного датасета из S3 (RustFS) в PostgreSQL"""

    @task
    def ensure_target_table() -> None:
        """Создание таблицы """
        hook = PostgresHook(postgres_conn_id=PG_CONN_ID)
        with hook.get_conn() as conn, conn.cursor() as cur:
            cur.execute(CREATE_TABLE_SQL)
        logger.info("Target table %s.%s is ready", SCHEMA, TABLE)

    @task
    def extract_from_s3() -> str:
        """Скачивает CSV-файл из S3-хранилища (RustFS) на локальный диск"""
        fd, local_path = tempfile.mkstemp(prefix="dataset_", suffix=".csv")
        os.close(fd)

        s3 = S3Hook(aws_conn_id=S3_CONN_ID)
        s3.get_conn().download_file(S3_BUCKET, S3_KEY, local_path)
        size = os.path.getsize(local_path)
        logger.info(
            "Downloaded s3://%s/%s -> %s (%d bytes)",
            S3_BUCKET, S3_KEY, local_path, size,
        )
        return local_path

    @task
    def load_to_postgres(file_path: str) -> str:
        """Загружает данные из локального CSV-файла в таблицу PostgreSQL"""
        hook = PostgresHook(postgres_conn_id=PG_CONN_ID)
        with hook.get_conn() as conn, conn.cursor() as cur:
            cur.execute(f"TRUNCATE TABLE {SCHEMA}.{TABLE}")
            with open(file_path, encoding="utf-8") as csv_file:
                cur.copy_expert(COPY_SQL, csv_file)
        logger.info("COPY to %s.%s finished successfully", SCHEMA, TABLE)
        return file_path

    @task
    def validate_and_cleanup(file_path: str) -> None:
        """Проверка целостности загруженных данных и очистка временные файлы"""
        try:
            with open(file_path, newline="", encoding="utf-8") as f:
                reader = csv.reader(f, delimiter=CSV_DELIMITER)
                next(reader, None)  # header
                file_rows = sum(1 for _ in reader)

            hook = PostgresHook(postgres_conn_id=PG_CONN_ID)
            db_rows = hook.get_first(
                f"SELECT count(*) FROM {SCHEMA}.{TABLE}")[0]

            logger.info("Rows in file: %d, rows in postgres: %d",
                        file_rows, db_rows)
            if file_rows != db_rows:
                raise ValueError(
                    f"Row count mismatch: file={file_rows}, postgres={db_rows}"
                )
        finally:
            if os.path.exists(file_path):
                os.remove(file_path)
                logger.info("Temporary file %s removed", file_path)

    table_ready = ensure_target_table()
    downloaded_path = extract_from_s3()

    table_ready >> downloaded_path
    loaded_path = load_to_postgres(downloaded_path)
    validate_and_cleanup(loaded_path)


s3_to_postgres_pipeline()

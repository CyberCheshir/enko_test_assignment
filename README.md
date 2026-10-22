# Тестовое задание
### <u>На позицию Data Engineer</u>


1. Работа с Jupyter и pandas, результат ipynb-файл со скриптом:
    - Считать данные из <code>"test_dataset.csv"</code>
    - Вывести основные статистические метрики по каждому числовому столбцу: 
	    - кол-во записей, 
	    - min, max, среднее, 
	    - стандартное отклонение
    - Вывести типы данных каждого столбца

2. Работа с Airflow, py-файл с дагом и тасками:
    - Написать даг, который:
    - Считывает файл <code>"test_dataset.csv"</code> из $S3$
    - Записывает данные из файла в $PostgreSQL$ 1 к 1

3. Работа с $PostgreSQL$, результат sql-файл со скриптами:
    - написать скрипты, раскладывающие данные из <code>"test_dataset.csv"</code> по таблицам в 3НФ

4. Работа с ClickHouse, результат sql-файл со скриптом:
    - Написать view, который:
    - Подключается к $PostgreSQL$
    - Денормализует данные из 3НФ к виду, аналогичному <code>"test_dataset.csv"</code>

---

## Быстрый запуск платформы

Запустите сервисы:
```bash
docker compose up -d
```

### Сервисы платформы:
| Сервис | Адрес |
|---|---|
| **Airflow UI** | [http://localhost:8080](http://localhost:8080) |
| **RustFS S3 Console** | [http://localhost:9001](http://localhost:9001) |
| **ClickHouse Web Play** | [http://localhost:18123/play](http://localhost:18123/play) |
| **PostgreSQL** | `localhost:5432` (db: `airflow`) |

---

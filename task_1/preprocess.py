import pandas as pd

def preprocess_test_df(test_df : pd.DataFrame) -> pd.DataFrame:
    dtype_groups = {
        "float": ["lat", "lon", "price", "square"],
        "int": ["object_id"],
        "datetime": ["load_date"],
    }

    for col in dtype_groups["float"]:
        test_df[col] = pd.to_numeric(
            test_df[col].astype("string").str.replace(",", ".", regex=False),
            errors="coerce"
        )

    for col in dtype_groups["int"]:
        test_df[col] = pd.to_numeric(
            test_df[col], errors="coerce"
        ).astype("Int64")

    for col in dtype_groups["datetime"]:
        test_df[col] = pd.to_datetime(
            test_df[col], errors="coerce"
        )

    excluded_cols = [
        col
        for cols in dtype_groups.values()
        for col in cols
    ]

    str_cols = test_df.columns.difference(excluded_cols)
    test_df[str_cols] = test_df[str_cols].astype(str)
    return test_df
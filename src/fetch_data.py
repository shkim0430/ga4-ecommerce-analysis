"""sql/ 쿼리를 실행해 outputs/ 폴더에 CSV로 저장한다."""

from pathlib import Path

import pandas as pd

from bq_client import run_query, run_query_string

OUTPUT_DIR = Path("outputs")

QUERY_TO_CSV = {
    "sql/02_channel_performance.sql": "outputs/channel_performance.csv",
    "sql/03_conversion_funnel.sql": "outputs/funnel.csv",
}

COHORT_SQL_PATH = Path("sql/01_cohort_repurchase.sql")
COHORT_SEPARATOR = "-- ========="

SEGMENT_SQL_PATH = Path("sql/04_customer_segments.sql")
SEGMENT_SEPARATOR = "-- ========="


def _save_csv(df: pd.DataFrame, output_path: str) -> None:
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, index=False, encoding="utf-8-sig")
    print(f"✅ 저장: {path} ({len(df)}행)")


def fetch_simple_queries() -> None:
    for sql_path, csv_path in QUERY_TO_CSV.items():
        df = run_query(sql_path)
        _save_csv(df, csv_path)


def fetch_cohort_queries() -> None:
    sql_text = COHORT_SQL_PATH.read_text(encoding="utf-8")
    monthly_sql, weekly_sql = sql_text.split(COHORT_SEPARATOR, 1)

    print(f"▶ 실행 중: {COHORT_SQL_PATH} (monthly)")
    monthly_df = run_query_string(monthly_sql)
    _save_csv(monthly_df, "outputs/cohort_monthly.csv")

    print(f"▶ 실행 중: {COHORT_SQL_PATH} (weekly)")
    weekly_df = run_query_string(weekly_sql)
    _save_csv(weekly_df, "outputs/cohort_weekly.csv")


def fetch_segment_queries() -> None:
    sql_text = SEGMENT_SQL_PATH.read_text(encoding="utf-8")
    pareto_sql, segment_matrix_sql = sql_text.split(SEGMENT_SEPARATOR, 1)

    print(f"▶ 실행 중: {SEGMENT_SQL_PATH} (pareto)")
    pareto_df = run_query_string(pareto_sql)
    _save_csv(pareto_df, "outputs/pareto.csv")

    print(f"▶ 실행 중: {SEGMENT_SQL_PATH} (segment_matrix)")
    segment_matrix_df = run_query_string(segment_matrix_sql)
    _save_csv(segment_matrix_df, "outputs/segment_matrix.csv")


if __name__ == "__main__":
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    fetch_simple_queries()
    fetch_cohort_queries()
    fetch_segment_queries()

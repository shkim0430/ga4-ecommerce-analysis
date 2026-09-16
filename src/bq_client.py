"""BigQuery 클라이언트 래퍼 — ADC 인증으로 쿼리를 실행하고 결과를 DataFrame으로 반환한다."""

import sys
from pathlib import Path

import pandas as pd
from google.cloud import bigquery

# Windows 콘솔(cp949)에서도 이모지/한글 print가 깨지지 않도록 stdout을 UTF-8로 고정한다.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except AttributeError:
    pass

PROJECT_ID = "ga4-ecommerce-508803"

_client = None


def _get_client() -> bigquery.Client:
    global _client
    if _client is None:
        _client = bigquery.Client(project=PROJECT_ID)
    return _client


def _first_statement(sql_text: str) -> str:
    for fragment in sql_text.split(";"):
        lines = [
            line
            for line in fragment.splitlines()
            if line.strip() and not line.strip().startswith("--")
        ]
        if lines:
            return fragment
    raise ValueError("실행할 SQL 문을 찾을 수 없습니다.")


def run_query_string(sql: str) -> pd.DataFrame:
    client = _get_client()
    job = client.query(sql)
    df = job.result().to_dataframe()
    print(f"  처리 바이트: {job.total_bytes_processed:,} bytes / 반환 행 수: {len(df):,}행")
    return df


def run_query(sql_path: str) -> pd.DataFrame:
    print(f"▶ 실행 중: {sql_path}")
    sql_text = Path(sql_path).read_text(encoding="utf-8")
    statement = _first_statement(sql_text)
    return run_query_string(statement)

"""sql/08_weekly_kpi.sql 결과로 주차별 KPI 엑셀 리포트(outputs/reports/weekly_YYYY-MM-DD.xlsx)를 만든다."""

import argparse
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill

from bq_client import run_query_string

SQL_PATH = Path("sql/08_weekly_kpi.sql")
SQL_SEPARATOR = "-- ========="
REPORT_DIR = Path("outputs/reports")

FIRST_WEEK = date(2020, 11, 2)
LAST_WEEK = date(2021, 1, 25)

DROP_THRESHOLD = -0.10
WOW_FORMAT = "+0.0%;-0.0%;0.0%"

KPI_ROWS = [
    ("visitors", "방문자 (명)", "#,##0", True),
    ("view_item_users", "상품 조회 유저 (명)", "#,##0", True),
    ("add_to_cart_users", "장바구니 유저 (명)", "#,##0", True),
    ("purchase_users", "구매 유저 (명)", "#,##0", True),
    ("conversion_pct", "구매 전환율 (%)", '0.00"%"', False),
    ("revenue", "매출", "#,##0", False),
]

ANOMALY_WEEKS = {
    "add_to_cart_users": {date(2020, 11, 2), date(2020, 11, 9), date(2020, 11, 16)},
    "revenue": {date(2021, 1, 25)},
}
ANOMALY_NOTES = {
    "add_to_cart_users": "이상 구간: add_to_cart 추적 누락(2020-11-02~11-15, 11-16 재개 후 11-21~22 다시 0건)",
    "revenue": "이상 구간: 2021-01-26 이후 purchase 매출 NULL 다수(과소 집계)",
}
ITEM_ANOMALY_WEEKS = {date(2021, 1, 25)}
ITEM_ANOMALY_NOTE = "이상 구간: 2021-01-26 이후 item_revenue NULL 다수(과소 집계)"
DISTINCT_NOTE = "주 단위 distinct 유저 (주별 합산 금지)"

RED_FILL = PatternFill("solid", start_color="FFC7CE")
RED_FONT = Font(color="9C0006", bold=True)
GRAY_FILL = PatternFill("solid", start_color="D9D9D9")
HEADER_FILL = PatternFill("solid", start_color="1F3864")
HEADER_FONT = Font(color="FFFFFF", bold=True)
TITLE_FONT = Font(size=14, bold=True)


def fetch_weekly_data() -> tuple[pd.DataFrame, pd.DataFrame]:
    sql_text = SQL_PATH.read_text(encoding="utf-8")
    kpi_sql, items_sql = sql_text.split(SQL_SEPARATOR, 1)

    print(f"▶ 실행 중: {SQL_PATH} (주차별 KPI)")
    kpi_df = run_query_string(kpi_sql)
    print(f"▶ 실행 중: {SQL_PATH} (주차별 상품 매출 상위 5)")
    items_df = run_query_string(items_sql)

    kpi_df["week_start"] = pd.to_datetime(kpi_df["week_start"]).dt.date
    items_df["week_start"] = pd.to_datetime(items_df["week_start"]).dt.date
    return kpi_df.set_index("week_start").sort_index(), items_df


def wow_change(current: float, previous) -> float | None:
    if previous is None or pd.isna(previous) or previous == 0:
        return None
    return (current - previous) / previous


def style_header(sheet, row: int, columns: int) -> None:
    for col in range(1, columns + 1):
        cell = sheet.cell(row=row, column=col)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center", vertical="center")


def set_widths(sheet, widths: list[int]) -> None:
    for index, width in enumerate(widths, start=1):
        sheet.column_dimensions[chr(64 + index)].width = width


def write_wow_cell(cell, change, is_anomaly: bool) -> None:
    cell.alignment = Alignment(horizontal="center")
    if change is None:
        cell.value = "-"
    else:
        cell.value = change
        cell.number_format = WOW_FORMAT
    if is_anomaly:
        cell.fill = GRAY_FILL
    elif change is not None and change <= DROP_THRESHOLD:
        cell.fill = RED_FILL
        cell.font = RED_FONT


def build_summary_sheet(sheet, week: date, kpi: pd.DataFrame) -> None:
    prev_week = week - timedelta(days=7)
    current = kpi.loc[week]
    previous = kpi.loc[prev_week] if prev_week in kpi.index else None

    sheet["A1"] = f"주간 KPI 리포트  {week} ~ {week + timedelta(days=6)}"
    sheet["A1"].font = TITLE_FONT
    sheet["A2"] = "데이터: bigquery-public-data.ga4_obfuscated_sample_ecommerce (난독화 샘플, 절대값은 참고용)"
    if previous is None:
        sheet["A3"] = "첫 주라 전주 데이터가 없어 전주 대비는 '-'로 표시합니다."

    headers = ["지표", "이번 주", "전주", "전주 대비", "비고"]
    for col, header in enumerate(headers, start=1):
        sheet.cell(row=5, column=col, value=header)
    style_header(sheet, 5, len(headers))

    for offset, (key, label, number_format, is_distinct) in enumerate(KPI_ROWS):
        row = 6 + offset
        anomaly_weeks = ANOMALY_WEEKS.get(key, set())
        current_anomaly = week in anomaly_weeks
        previous_anomaly = prev_week in anomaly_weeks

        sheet.cell(row=row, column=1, value=label)
        value_cell = sheet.cell(row=row, column=2, value=float(current[key]))
        value_cell.number_format = number_format
        if current_anomaly:
            value_cell.fill = GRAY_FILL

        previous_cell = sheet.cell(row=row, column=3)
        if previous is None:
            previous_cell.value = "-"
            previous_cell.alignment = Alignment(horizontal="center")
        else:
            previous_cell.value = float(previous[key])
            previous_cell.number_format = number_format

        previous_value = None if previous is None else float(previous[key])
        change = wow_change(float(current[key]), previous_value)
        write_wow_cell(sheet.cell(row=row, column=4), change, current_anomaly or previous_anomaly)

        notes = []
        if current_anomaly:
            notes.append(ANOMALY_NOTES[key])
        elif previous_anomaly:
            notes.append("전주가 이상 구간이라 전주 대비를 신뢰할 수 없음 (" + ANOMALY_NOTES[key].split(":")[0] + ")")
        if is_distinct:
            notes.append(DISTINCT_NOTE)
        sheet.cell(row=row, column=5, value=" / ".join(notes))

    legend_row = 6 + len(KPI_ROWS) + 1
    sheet.cell(row=legend_row, column=1, value="표시 규칙")
    sheet.cell(row=legend_row, column=1).font = Font(bold=True)
    sheet.cell(row=legend_row + 1, column=1, value="빨강")
    sheet.cell(row=legend_row + 1, column=1).fill = RED_FILL
    sheet.cell(row=legend_row + 1, column=2, value="전주 대비 -10% 이하")
    sheet.cell(row=legend_row + 2, column=1, value="회색")
    sheet.cell(row=legend_row + 2, column=1).fill = GRAY_FILL
    sheet.cell(row=legend_row + 2, column=2, value="이상 구간 (값 또는 전주 값을 신뢰할 수 없어 강조 규칙 제외)")
    sheet.cell(row=legend_row + 3, column=1, value="-")
    sheet.cell(row=legend_row + 3, column=2, value="계산 불가 (전주 데이터 없음 또는 전주 값 0)")

    set_widths(sheet, [22, 16, 16, 14, 90])


def build_items_sheet(sheet, week: date, items: pd.DataFrame) -> None:
    prev_week = week - timedelta(days=7)
    current_rows = items[items["week_start"] == week].sort_values(["rank_in_week", "item_name"])
    previous_rows = items[items["week_start"] == prev_week]
    previous_lookup = {
        row.item_name: (int(row.rank_in_week), float(row.item_revenue)) for row in previous_rows.itertuples()
    }
    has_previous = not previous_rows.empty

    sheet["A1"] = f"주별 상품 매출 상위 5개  {week} ~ {week + timedelta(days=6)}"
    sheet["A1"].font = TITLE_FONT
    sheet["A2"] = "item_revenue 합 기준, 표기 차이 미보정 (Longsleeve Charcoal/Ash, Womens Google Striped LS는 이름 그대로 집계)"
    if not has_previous:
        sheet["A3"] = "첫 주라 전주 데이터가 없어 전주 칸은 '-'로 표시합니다."

    headers = ["순위", "상품", "이번 주 매출", "전주 순위", "전주 매출", "전주 대비", "비고"]
    for col, header in enumerate(headers, start=1):
        sheet.cell(row=5, column=col, value=header)
    style_header(sheet, 5, len(headers))

    current_anomaly = week in ITEM_ANOMALY_WEEKS
    previous_anomaly = prev_week in ITEM_ANOMALY_WEEKS

    for offset, row_data in enumerate(current_rows.itertuples()):
        row = 6 + offset
        revenue = float(row_data.item_revenue)
        sheet.cell(row=row, column=1, value=int(row_data.rank_in_week)).alignment = Alignment(horizontal="center")
        sheet.cell(row=row, column=2, value=row_data.item_name)
        revenue_cell = sheet.cell(row=row, column=3, value=revenue)
        revenue_cell.number_format = "#,##0"
        if current_anomaly:
            revenue_cell.fill = GRAY_FILL

        rank_cell = sheet.cell(row=row, column=4)
        previous_revenue_cell = sheet.cell(row=row, column=5)
        note = ""
        change = None
        if not has_previous:
            rank_cell.value = "-"
            previous_revenue_cell.value = "-"
        elif row_data.item_name in previous_lookup:
            previous_rank, previous_revenue = previous_lookup[row_data.item_name]
            rank_cell.value = previous_rank
            previous_revenue_cell.value = previous_revenue
            previous_revenue_cell.number_format = "#,##0"
            change = wow_change(revenue, previous_revenue)
        else:
            rank_cell.value = "5위 밖"
            previous_revenue_cell.value = "-"
            note = "전주 상위 5개에 없어 전주 매출을 알 수 없음"
        rank_cell.alignment = Alignment(horizontal="center")
        previous_revenue_cell.alignment = Alignment(horizontal="center" if not isinstance(previous_revenue_cell.value, float) else "right")

        write_wow_cell(sheet.cell(row=row, column=6), change, current_anomaly or previous_anomaly)
        if current_anomaly:
            note = (note + " / " if note else "") + ITEM_ANOMALY_NOTE
        elif previous_anomaly:
            note = (note + " / " if note else "") + "전주가 이상 구간이라 전주 대비를 신뢰할 수 없음"
        sheet.cell(row=row, column=7, value=note)

    set_widths(sheet, [8, 44, 16, 12, 16, 14, 70])


def build_definitions_sheet(sheet, week: date) -> None:
    sheet["A1"] = "정의와 한계"
    sheet["A1"].font = TITLE_FONT
    rows = [
        ("데이터", "bigquery-public-data.ga4_obfuscated_sample_ecommerce, 2020-11-01 ~ 2021-01-31. 난독화된 샘플이라 절대값은 실제와 다를 수 있습니다."),
        ("주 기준", "DATE_TRUNC(..., WEEK(MONDAY)), 코호트와 동일. 완전한 주 13개(2020-11-02 ~ 2021-01-25 시작)만 사용하고, 11/1 하루뿐인 2020-10-26 주는 제외합니다."),
        ("visitors", "해당 주에 이벤트가 있는 distinct user_pseudo_id."),
        ("view_item / add_to_cart 유저", "해당 주에 각 이벤트를 1회 이상 경험한 distinct 유저."),
        ("purchase_users", "해당 주에 purchase 이벤트를 경험한 distinct 유저. 주 단위 distinct라 주별 유저 수는 합산하면 안 됩니다 (13주 단순 합 4,686 vs 완전 주 distinct 4,406)."),
        ("conversion_pct", "purchase_users ÷ visitors × 100."),
        ("revenue", "transaction_id가 있는 purchase 이벤트의 ecommerce.purchase_revenue 합 (UNNEST 하지 않은 이벤트 단위). transaction_id가 없는 purchase 23건(2020-11-01~11-08, 합 1,328)은 제외되어 13주 합이 360,837입니다."),
        ("전주 대비", "(이번 주 - 전주) ÷ 전주, 모든 지표 동일하게 상대 변화율. 전주 값이 없거나 0이면 '-'. -10% 이하는 빨강으로 강조합니다."),
        ("이상 구간 (회색)", "add_to_cart 추적 누락(2020-11-02~11-15, 11-16에 재개되었으나 11-21~22는 다시 0건)은 2020-11-02/11-09/11-16 주 장바구니 유저에 적용. 2021-01-26 이후 purchase_revenue/item_revenue NULL 다수는 2021-01-25 주 매출과 상품 매출에 적용. 이 칸은 값이나 전주 값을 신뢰할 수 없어 빨강 강조에서 제외하고 회색으로 표시합니다."),
        ("상품 매출", "purchase 이벤트의 item_name별 SUM(item_revenue) 상위 5개 (동률은 공동 순위). 주간 상품 매출은 표기 차이 미보정입니다."),
        ("상품 전주 대비", "전주 상위 5개 안에 있는 상품만 전주 매출을 알 수 있습니다. 5위 밖이면 '5위 밖'으로 표시하며 전주 매출과 전주 대비는 알 수 없습니다."),
        ("해석 주의", "상대 비교 용도로만 활용하세요. 연말·연초(12-21 ~ 01-04 주)는 방문자와 구매가 계절적으로 줄어 -10% 이하 강조가 많이 나타납니다."),
        ("상세 정의", "docs/metric_definitions.md, docs/item_name_mapping.md"),
        ("생성", f"{datetime.now():%Y-%m-%d %H:%M} 생성, 대상 주 {week}"),
    ]
    sheet.cell(row=3, column=1, value="항목")
    sheet.cell(row=3, column=2, value="내용")
    style_header(sheet, 3, 2)
    for offset, (label, text) in enumerate(rows):
        row = 4 + offset
        sheet.cell(row=row, column=1, value=label).font = Font(bold=True)
        content = sheet.cell(row=row, column=2, value=text)
        content.alignment = Alignment(wrap_text=True, vertical="top")
        sheet.cell(row=row, column=1).alignment = Alignment(vertical="top")
    set_widths(sheet, [26, 120])


def build_report(week: date, kpi: pd.DataFrame, items: pd.DataFrame) -> Path:
    workbook = Workbook()
    summary = workbook.active
    summary.title = "① 요약"
    build_summary_sheet(summary, week, kpi)
    build_items_sheet(workbook.create_sheet("② 상품 매출 상위5"), week, items)
    build_definitions_sheet(workbook.create_sheet("③ 정의·한계"), week)

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / f"weekly_{week}.xlsx"
    workbook.save(path)
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="주간 KPI 엑셀 리포트 생성")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--week", help="리포트 대상 주의 시작일(월요일) YYYY-MM-DD")
    group.add_argument("--all", action="store_true", help="완전한 13주 리포트를 일괄 생성")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    target = None
    if args.week:
        try:
            target = datetime.strptime(args.week, "%Y-%m-%d").date()
        except ValueError:
            sys.exit(f"--week 형식이 올바르지 않습니다: {args.week} (예: 2020-11-02)")
        if target.weekday() != 0 or not FIRST_WEEK <= target <= LAST_WEEK:
            sys.exit(f"{target}은(는) 리포트 대상 주가 아닙니다. {FIRST_WEEK} ~ {LAST_WEEK} 사이의 월요일이어야 합니다.")

    kpi, items = fetch_weekly_data()
    weeks = list(kpi.index)

    if target is not None:
        if target not in weeks:
            valid = ", ".join(str(w) for w in weeks)
            sys.exit(f"{target}은(는) 리포트 대상 주가 아닙니다. 가능한 주: {valid}")
        weeks = [target]

    for week in weeks:
        path = build_report(week, kpi, items)
        print(f"✅ 저장: {path}")


if __name__ == "__main__":
    main()

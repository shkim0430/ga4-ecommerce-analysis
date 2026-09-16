"""outputs/ 의 CSV 결과를 읽어 outputs/figures/ 에 PNG 시각화를 저장한다."""

import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

# Windows 콘솔(cp949)에서도 이모지 print가 깨지지 않도록 stdout을 UTF-8로 고정한다.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except AttributeError:
    pass

plt.rcParams["font.family"] = "Malgun Gothic"
plt.rcParams["axes.unicode_minus"] = False

OUTPUT_DIR = Path("outputs")
FIGURES_DIR = OUTPUT_DIR / "figures"

EXCLUDED_CHANNEL_LABEL = "(data deleted)"


def _savefig(fig: plt.Figure, filename: str) -> Path:
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    path = FIGURES_DIR / filename
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    return path


def plot_funnel() -> Path:
    df = pd.read_csv(OUTPUT_DIR / "funnel.csv")
    df = df.sort_values("step")
    df["step_label"] = df["step"].str.split("_", n=1).str[1]

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.barh(df["step_label"], df["users"], color="#4C72B0")
    ax.invert_yaxis()

    for i, row in enumerate(df.itertuples()):
        if pd.isna(row.step_conversion_pct):
            label = f"{row.users:,}명 (기준)"
        else:
            label = (
                f"{row.users:,}명 "
                f"(직전 {row.step_conversion_pct:.1f}% / 누적 {row.overall_conversion_pct:.1f}%)"
            )
        ax.text(row.users, i, f"  {label}", va="center", ha="left")

    ax.set_xlabel("유저 수")
    ax.set_title("구매 전환 퍼널 (2020-11 ~ 2021-01)")
    ax.set_xlim(0, df["users"].max() * 1.6)

    return _savefig(fig, "01_funnel.png")


def _cohort_retention_pivot(df: pd.DataFrame, cohort_col: str, offset_col: str) -> pd.DataFrame:
    pivot = df.pivot(index=cohort_col, columns=offset_col, values="unique_users")
    base = pivot[0]
    retention = pivot.div(base, axis=0) * 100
    return retention


def plot_cohort_monthly() -> Path:
    df = pd.read_csv(OUTPUT_DIR / "cohort_monthly.csv")
    retention = _cohort_retention_pivot(df, "cohort_month", "months_since_first")
    retention = retention.drop(columns=0)
    retention = retention.dropna(how="all")
    retention.index = pd.to_datetime(retention.index).strftime("%Y-%m")

    fig, ax = plt.subplots(figsize=(max(6, len(retention.columns) * 1.2), max(4, len(retention) * 0.8)))
    sns.heatmap(
        retention,
        annot=True,
        fmt=".1f",
        cmap="YlGnBu",
        vmin=0,
        vmax=5,
        ax=ax,
        cbar_kws={"label": "재구매율 (%)"},
    )
    ax.set_title("월간 코호트 재구매율 (%)")
    ax.set_xlabel("경과 개월 수")
    ax.set_ylabel("코호트 월")

    return _savefig(fig, "02_cohort_monthly.png")


def plot_cohort_weekly() -> Path:
    df = pd.read_csv(OUTPUT_DIR / "cohort_weekly.csv")
    retention = _cohort_retention_pivot(df, "cohort_week", "weeks_since_first")
    retention = retention.drop(columns=0)
    retention.index = pd.to_datetime(retention.index).strftime("%Y-%m-%d")

    mask = retention.isna()

    fig, ax = plt.subplots(figsize=(max(10, len(retention.columns) * 0.9), max(5, len(retention) * 0.5)))
    ax.set_facecolor("lightgray")
    sns.heatmap(
        retention,
        annot=True,
        fmt=".1f",
        cmap="YlGnBu",
        vmin=0,
        vmax=4,
        mask=mask,
        annot_kws={"size": 7},
        ax=ax,
        cbar_kws={"label": "재구매율 (%)"},
    )
    ax.set_title("주간 코호트 재구매율 (%)")
    ax.set_xlabel("경과 주차")
    ax.set_ylabel("코호트 주")

    return _savefig(fig, "03_cohort_weekly.png")


def plot_channel_performance() -> Path:
    df = pd.read_csv(OUTPUT_DIR / "channel_performance.csv")

    is_data_deleted = (df["source"] == EXCLUDED_CHANNEL_LABEL) | (df["medium"] == EXCLUDED_CHANNEL_LABEL)
    is_other = (df["source"] == "<Other>") | (df["medium"] == "<Other>")
    is_low_users = df["users"] < 100
    df = df[~(is_data_deleted | is_other | is_low_users)].copy()

    df["label"] = df["source"] + " / " + df["medium"]
    df = df.sort_values("users", ascending=False)

    bar_color = "#4C72B0"
    line_color = "#DD8452"

    fig, ax1 = plt.subplots(figsize=(10, 6))
    bars = ax1.bar(df["label"], df["users"], color=bar_color, label="유저 수")
    ax1.set_ylabel("유저 수", color=bar_color)
    ax1.tick_params(axis="y", labelcolor=bar_color)
    plt.setp(ax1.get_xticklabels(), rotation=45, ha="right")

    ax2 = ax1.twinx()
    lines = ax2.plot(
        df["label"],
        df["purchase_rate_pct"],
        color=line_color,
        marker="o",
        label="구매 전환율 (%)",
    )
    ax2.set_ylabel("구매 전환율 (%)", color=line_color)
    ax2.tick_params(axis="y", labelcolor=line_color)

    ax1.set_title("채널별 유입 규모와 구매 전환율")

    handles = [bars, lines[0]]
    labels = [h.get_label() for h in handles]
    fig.legend(handles, labels, loc="lower center", ncol=2, bbox_to_anchor=(0.5, -0.32))

    return _savefig(fig, "04_channel_performance.png")


def plot_pareto() -> Path:
    df = pd.read_csv(OUTPUT_DIR / "pareto.csv")

    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(df["user_percentile_group"], df["revenue_share_pct"], color="#4C72B0")

    for bar, value in zip(bars, df["revenue_share_pct"]):
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 1,
            f"{value:.1f}%",
            ha="center",
            va="bottom",
        )

    ax.axhline(80, color="red", linestyle="--")
    ax.text(len(df) - 1, 80 + 1.5, "80% 기준선", color="red", ha="right")

    ax.set_xlabel("유저 상위 %")
    ax.set_ylabel("누적 매출 비중 (%)")
    ax.set_title("매출 집중도 (Pareto 분석)")
    ax.set_ylim(0, 110)

    return _savefig(fig, "05_pareto.png")


def plot_segment_matrix() -> Path:
    df = pd.read_csv(OUTPUT_DIR / "segment_matrix.csv")

    frequency_order = ["1회", "2회", "3회+"]
    monetary_order = ["Low", "Mid", "High", "VIP"]

    user_count_pivot = (
        df.pivot(index="frequency_segment", columns="monetary_segment", values="users")
        .reindex(index=frequency_order, columns=monetary_order)
    )
    revenue_pivot = (
        df.pivot(index="frequency_segment", columns="monetary_segment", values="revenue_share_pct")
        .reindex(index=frequency_order, columns=monetary_order)
    )

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    sns.heatmap(
        user_count_pivot,
        annot=True,
        fmt=",.0f",
        cmap="Blues",
        ax=ax1,
        cbar_kws={"label": "유저 수"},
    )
    ax1.set_title("세그먼트별 유저 수")
    ax1.set_xlabel("금액 세그먼트")
    ax1.set_ylabel("빈도 세그먼트")

    sns.heatmap(
        revenue_pivot,
        annot=True,
        fmt=".1f",
        cmap="Oranges",
        ax=ax2,
        cbar_kws={"label": "매출 비중 (%)"},
    )
    ax2.set_title("세그먼트별 매출 비중 (%)")
    ax2.set_xlabel("금액 세그먼트")
    ax2.set_ylabel("빈도 세그먼트")

    fig.suptitle("구매 빈도 × 금액대 세그먼트 매트릭스")

    return _savefig(fig, "06_segment_matrix.png")


if __name__ == "__main__":
    for plot_fn in (
        plot_funnel,
        plot_cohort_monthly,
        plot_cohort_weekly,
        plot_channel_performance,
        plot_pareto,
        plot_segment_matrix,
    ):
        path = plot_fn()
        print(f"✅ 저장: {path}")

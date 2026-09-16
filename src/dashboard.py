"""outputs/*.csv 만 읽어 렌더링하는 Streamlit 대시보드. BigQuery 호출 없음."""

from pathlib import Path

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

OUTPUT_DIR = Path(__file__).parent.parent / "outputs"

EXCLUDED_CHANNEL_LABEL = "(data deleted)"

PAGES = [
    "📊 Executive Summary",
    "🔽 구매 전환 퍼널",
    "📅 코호트 재구매율",
    "🚪 채널 성과",
    "👥 고객 세그먼트",
]

FREQUENCY_ORDER = ["1회", "2회", "3회+"]
MONETARY_ORDER = ["Low", "Mid", "High", "VIP"]


@st.cache_data
def load_csv(filename: str) -> pd.DataFrame:
    return pd.read_csv(OUTPUT_DIR / filename)


def cohort_retention_pivot(df: pd.DataFrame, cohort_col: str, offset_col: str) -> pd.DataFrame:
    pivot = df.pivot(index=cohort_col, columns=offset_col, values="unique_users")
    base = pivot[0]
    retention = pivot.div(base, axis=0) * 100
    return retention.drop(columns=0)


def render_sidebar() -> str:
    with st.sidebar:
        st.title("GA4 이커머스 분석")
        st.markdown(
            "GA4 + BigQuery 공개 데이터셋으로 Google Merchandise Store의 이커머스 데이터를 "
            "분석한 포트폴리오 프로젝트입니다. 구매 전환 퍼널, 채널 성과, 코호트 재구매율, "
            "고객 세그먼트 분석을 통해 매출 개선 우선순위를 도출합니다."
        )
        st.markdown("**데이터 기간**: 2020-11-01 ~ 2021-01-31")
        st.markdown("**데이터 규모**: 방문자 270,154명 / 구매 유저 4,419명")

        page = st.radio("페이지 선택", PAGES)

        st.caption("데이터: bigquery-public-data.ga4_obfuscated_sample_ecommerce (난독화 샘플)")

    return page


def render_executive_summary() -> None:
    st.title("Executive Summary")

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("총 방문자", "270,154")
    col2.metric("구매 유저", "4,419")
    col3.metric("전체 구매 전환율", "1.64%")
    col4.metric("매출 상위 20% 유저의 매출 비중", "56.7%")

    st.divider()

    st.markdown("#### 가장 큰 매출 손실 지점은 체크아웃 이탈")
    st.markdown(
        "상품을 장바구니에 담고 체크아웃까지 진행한 유저의 54.5%가 결제 없이 이탈합니다. "
        "이는 업계 평균(30~40%) 대비 심각한 수준으로, 배송비 사전 노출·게스트 체크아웃 등 "
        "결제 페이지 최적화의 임팩트가 가장 큽니다."
    )

    st.markdown('#### 매출의 42%는 "1회 중가 구매자" 하나의 세그먼트에서 발생')
    st.markdown(
        "1,623명의 1회 Mid($50~$200) 구매자가 전체 매출의 42.1%를 담당합니다. 이 세그먼트가 "
        "사이트의 백본이며, 재구매 유도 대상이자 리텐션 파이프라인의 진입점입니다."
    )

    st.markdown("#### 매출은 헤비 유저가 아닌 대중 구매자에 의존")
    st.markdown(
        "상위 20% 유저가 매출의 56.7%를 차지해, 전형적인 20/80 법칙의 80%와는 거리가 "
        "있습니다. 즉 VIP 리텐션 전략보다 전체 구매자 수를 늘리는 전략의 레버리지가 더 "
        "큽니다."
    )

    st.markdown("#### 자체 도메인 리퍼럴 채널의 전환율이 가장 높음")
    st.markdown(
        "shop.googlemerchandisestore.com 리퍼럴 채널의 CVR은 2.21%로 다른 유입 채널(1.5% "
        "내외) 대비 0.7%p 높습니다. 이 채널은 GA4에서 결제·로그인 페이지 이동 중 세션이 "
        "끊긴 재방문자가 잡히는 경우가 많아, 신규 유입보다 재방문 유저의 구매 의도가 강함을 "
        "시사합니다. 다만 이 채널의 절대 규모는 전체 유저의 5% 수준이라, 신규 유입의 전환율 "
        "자체를 개선하는 것이 우선 과제입니다."
    )

    st.markdown("#### 재구매율은 후반 코호트로 갈수록 개선")
    st.markdown(
        "첫 주(W1) 재구매율이 2020-11-02 코호트 2.6%에서 2021-01-18 코호트 3.5%로 "
        "상승했습니다. 사이트의 신규→재구매 전환 능력이 시간이 갈수록 나아지고 있음을 "
        "시사합니다."
    )


def render_funnel() -> None:
    st.title("구매 전환 퍼널")

    df = load_csv("funnel.csv").sort_values("step").copy()
    df["step_label"] = df["step"].str.split("_", n=1).str[1]

    fig = go.Figure(
        go.Funnel(
            y=df["step_label"],
            x=df["users"],
            textinfo="value+percent initial+percent previous",
        )
    )
    fig.update_layout(title="구매 전환 퍼널")
    st.plotly_chart(fig, use_container_width=True)

    st.dataframe(df, use_container_width=True)

    st.info("체크아웃 → 구매 이탈률 54.5%가 가장 큰 매출 손실 지점")


def render_cohort() -> None:
    st.title("코호트 재구매율")

    tab_monthly, tab_weekly = st.tabs(["월간", "주간"])

    with tab_monthly:
        df = load_csv("cohort_monthly.csv")
        retention = cohort_retention_pivot(df, "cohort_month", "months_since_first")
        retention.index = pd.to_datetime(retention.index).strftime("%Y-%m")
        retention.index = retention.index.astype(str)

        fig = px.imshow(
            retention,
            text_auto=".1f",
            color_continuous_scale="YlGnBu",
            zmin=0,
            zmax=5,
            labels=dict(x="경과 개월 수", y="코호트 월", color="재구매율 (%)"),
        )
        fig.update_layout(
            title="월간 코호트 재구매율 (%)",
            yaxis=dict(
                type="category",
                tickmode="array",
                tickvals=list(range(len(retention.index))),
                ticktext=retention.index.tolist(),
            ),
        )
        st.plotly_chart(fig, use_container_width=True)

    with tab_weekly:
        df = load_csv("cohort_weekly.csv")
        retention = cohort_retention_pivot(df, "cohort_week", "weeks_since_first")
        retention.index = pd.to_datetime(retention.index).strftime("%Y-%m-%d")
        retention.index = retention.index.astype(str)

        fig = px.imshow(
            retention,
            text_auto=".1f",
            color_continuous_scale="YlGnBu",
            zmin=0,
            zmax=4,
            labels=dict(x="경과 주차", y="코호트 주", color="재구매율 (%)"),
        )
        fig.update_layout(
            title="주간 코호트 재구매율 (%)",
            plot_bgcolor="lightgray",
            yaxis=dict(
                type="category",
                tickmode="array",
                tickvals=list(range(len(retention.index))),
                ticktext=retention.index.tolist(),
            ),
        )
        st.plotly_chart(fig, use_container_width=True)


def render_channel_performance() -> None:
    st.title("채널 성과")

    df = load_csv("channel_performance.csv")

    is_data_deleted = (df["source"] == EXCLUDED_CHANNEL_LABEL) | (df["medium"] == EXCLUDED_CHANNEL_LABEL)
    is_other = (df["source"] == "<Other>") | (df["medium"] == "<Other>")
    is_low_users = df["users"] < 100
    df = df[~(is_data_deleted | is_other | is_low_users)].copy()

    df["label"] = df["source"] + " / " + df["medium"]
    df = df.sort_values("users", ascending=False)

    fig = go.Figure()
    fig.add_bar(x=df["label"], y=df["users"], name="유저 수", marker_color="#4C72B0")
    fig.add_trace(
        go.Scatter(
            x=df["label"],
            y=df["purchase_rate_pct"],
            name="구매 전환율 (%)",
            mode="lines+markers",
            marker_color="#DD8452",
            yaxis="y2",
        )
    )
    fig.update_layout(
        title="채널별 유입 규모와 구매 전환율",
        yaxis=dict(title="유저 수"),
        yaxis2=dict(title="구매 전환율 (%)", overlaying="y", side="right"),
        legend=dict(orientation="h", yanchor="bottom", y=-0.4, xanchor="center", x=0.5),
    )
    st.plotly_chart(fig, use_container_width=True)

    st.dataframe(
        df[
            [
                "source",
                "medium",
                "users",
                "purchasing_users",
                "purchase_rate_pct",
                "total_revenue",
                "arpu",
                "arppu",
            ]
        ],
        use_container_width=True,
    )


def render_segments() -> None:
    st.title("고객 세그먼트")

    pareto_df = load_csv("pareto.csv")
    fig_pareto = go.Figure(
        go.Bar(
            x=pareto_df["user_percentile_group"],
            y=pareto_df["revenue_share_pct"],
            marker_color="#4C72B0",
            text=pareto_df["revenue_share_pct"].map(lambda v: f"{v:.1f}%"),
            textposition="outside",
        )
    )
    fig_pareto.add_hline(
        y=80,
        line_dash="dash",
        line_color="red",
        annotation_text="80% 기준선",
        annotation_position="top left",
        annotation_font_color="red",
    )
    fig_pareto.update_layout(
        title="매출 집중도 (Pareto 분석)",
        xaxis_title="유저 상위 %",
        yaxis_title="누적 매출 비중 (%)",
        yaxis_range=[0, 110],
    )
    st.plotly_chart(fig_pareto, use_container_width=True)

    segment_df = load_csv("segment_matrix.csv")
    user_pivot = (
        segment_df.pivot(index="frequency_segment", columns="monetary_segment", values="users")
        .reindex(index=FREQUENCY_ORDER, columns=MONETARY_ORDER)
    )
    revenue_pivot = (
        segment_df.pivot(index="frequency_segment", columns="monetary_segment", values="revenue_share_pct")
        .reindex(index=FREQUENCY_ORDER, columns=MONETARY_ORDER)
    )

    col1, col2 = st.columns(2)
    with col1:
        fig_users = px.imshow(
            user_pivot,
            text_auto=",.0f",
            color_continuous_scale="Blues",
            labels=dict(x="금액 세그먼트", y="빈도 세그먼트", color="유저 수"),
        )
        fig_users.update_layout(title="세그먼트별 유저 수")
        st.plotly_chart(fig_users, use_container_width=True)

    with col2:
        fig_revenue = px.imshow(
            revenue_pivot,
            text_auto=".1f",
            color_continuous_scale="Oranges",
            labels=dict(x="금액 세그먼트", y="빈도 세그먼트", color="매출 비중 (%)"),
        )
        fig_revenue.update_layout(title="세그먼트별 매출 비중 (%)")
        st.plotly_chart(fig_revenue, use_container_width=True)


def main() -> None:
    st.set_page_config(
        page_title="GA4 이커머스 분석",
        layout="wide",
        initial_sidebar_state="expanded",
    )

    page = render_sidebar()

    if page == "📊 Executive Summary":
        render_executive_summary()
    elif page == "🔽 구매 전환 퍼널":
        render_funnel()
    elif page == "📅 코호트 재구매율":
        render_cohort()
    elif page == "🚪 채널 성과":
        render_channel_performance()
    elif page == "👥 고객 세그먼트":
        render_segments()


if __name__ == "__main__":
    main()

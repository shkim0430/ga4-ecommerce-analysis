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
    "🛍️ 상품 분석",
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
        st.markdown("**데이터 규모**: 방문자 270,154명 / 구매 유저 4,419명 (퍼널 전 단계 경험 기준 2,915명)")

        page = st.radio("페이지 선택", PAGES)

        st.caption("데이터: bigquery-public-data.ga4_obfuscated_sample_ecommerce (난독화 샘플)")

    return page


def render_executive_summary() -> None:
    st.title("Executive Summary")

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("총 방문자", "270,154")
    col2.metric("구매 유저", "2,915 (전 단계 경험 기준)")
    col3.metric("전체 구매 전환율", "1.08%")
    col4.metric("매출 상위 20% 유저의 매출 비중", "56.7%")

    st.divider()

    st.markdown("#### 가장 큰 매출 손실 지점은 장바구니 → 체크아웃 구간")
    st.markdown(
        "상품을 조회하고 장바구니에 담은 유저 12,539명 중 54.9%가 체크아웃으로 넘어가지 "
        "않습니다 (체크아웃 진입 5,656명). 체크아웃 이후 구매 완료율은 51.5%로 상대적으로 "
        "양호해, 매출 개선 레버리지는 결제 페이지보다 **장바구니 이탈 방지(저장 알림, 재고 "
        "긴급성 노출, 쿠폰 자동 적용 등)에 더 큽니다**."
    )
    st.caption(
        "add_to_cart 추적 누락 구간(11/2~11/15)을 제외하고 11/16 이후로 다시 계산하면 "
        "이탈률 55.2%로 결론이 유지됩니다."
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

    st.info(
        "장바구니 → 체크아웃 이탈률 54.9%가 가장 큰 매출 손실 지점 (교집합 기준 분석)\n\n"
        "add_to_cart 추적 누락 구간(11/2~11/15)을 제외하고 11/16 이후로 다시 계산하면 "
        "55.2%로 결론이 유지됩니다."
    )


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


def render_item_analysis() -> None:
    st.title("상품 분석")
    st.warning(
        "상품·카테고리 분석은 **상대 비교 전용**입니다. 조회 이벤트의 items 누락, item_name 표기 "
        "불일치, item_category 형식 불일치로 절대 전환율은 실제와 다를 수 있습니다. "
        "정의와 한계는 docs/metric_definitions.md를 참고하세요."
    )

    # (a) 상품 전환 비교
    st.header("상품 전환 비교")
    item_df = load_csv("item_funnel.csv")
    item_df["표본"] = item_df["low_sample"].map({True: "low_sample (구매 유저 30명 미만)", False: "표본 충분"})

    fig_item = px.scatter(
        item_df,
        x="view_to_cart_pct",
        y="cart_to_purchase_pct",
        size="cart_users",
        color="표본",
        hover_name="item_name",
        hover_data={"view_users": True, "cart_users": True, "purchase_users": True, "표본": False},
        color_discrete_map={
            "low_sample (구매 유저 30명 미만)": "#BBBBBB",
            "표본 충분": "#4C72B0",
        },
        labels={
            "view_to_cart_pct": "조회 → 장바구니 (%)",
            "cart_to_purchase_pct": "장바구니 → 구매 (%)",
        },
    )
    fig_item.update_layout(title="상품별 단계 전환율 (버블 크기 = 장바구니 유저 수)")
    st.plotly_chart(fig_item, use_container_width=True)

    low_count = int(item_df["low_sample"].sum())
    st.caption(
        f"조회 100명 이상 + 장바구니 500명 이상 상품 {len(item_df)}개 중 "
        f"low_sample(구매 유저 30명 미만) {low_count}개는 회색으로 표시했습니다. "
        "각 단계는 같은 상품을 조회 → 장바구니 → 구매까지 모두 경험한 유저(유저×상품 교집합) 기준입니다."
    )
    st.caption(
        "⚠️ view_item 이벤트의 37.3%(144,192 / 386,068)는 items 배열이 비어 있어 상품별 조회 유저가 "
        "과소 집계됩니다. 조회 기준 전환율은 실제보다 높게 나올 수 있습니다."
    )
    st.caption(
        "purchase의 표기가 달라 연결이 끊긴 3개 상품은 수동 매핑으로 보정했습니다 "
        "(docs/item_name_mapping.md). 매핑하지 않은 상품은 구매가 0이거나 과소 집계될 수 있습니다."
    )
    st.dataframe(
        item_df[
            [
                "item_name",
                "view_users",
                "cart_users",
                "purchase_users",
                "view_to_cart_pct",
                "cart_to_purchase_pct",
                "overall_conversion_pct",
                "low_sample",
            ]
        ].sort_values("view_users", ascending=False),
        use_container_width=True,
        hide_index=True,
    )

    st.divider()

    # (b) 카테고리 퍼널
    st.header("카테고리 퍼널")
    category_df = load_csv("category_funnel.csv").sort_values("view_users", ascending=False)
    category_df["비고"] = category_df["item_category"].map(
        lambda c: "과소 집계 가능" if c == "Home/Eco-Friendly/" else ""
    )

    top_categories = category_df.head(15).melt(
        id_vars="item_category",
        value_vars=["view_to_cart_pct", "cart_to_purchase_pct"],
        var_name="단계",
        value_name="전환율 (%)",
    )
    top_categories["단계"] = top_categories["단계"].map(
        {"view_to_cart_pct": "조회 → 장바구니", "cart_to_purchase_pct": "장바구니 → 구매"}
    )
    fig_category = px.bar(
        top_categories,
        x="전환율 (%)",
        y="item_category",
        color="단계",
        barmode="group",
        orientation="h",
        labels={"item_category": "카테고리"},
    )
    fig_category.update_layout(
        title="조회 유저 상위 15개 리프 카테고리의 단계 전환율",
        yaxis=dict(autorange="reversed"),
        height=650,
    )
    st.plotly_chart(fig_category, use_container_width=True)

    st.caption(
        "카테고리 퍼널은 **카테고리 안의 어떤 상품이든** 조회 → 장바구니 → 구매한 유저(유저×카테고리 교집합) "
        "기준이라 상품 퍼널보다 전환율이 높게 나옵니다. 두 퍼널의 전환율을 직접 비교하지 마세요. "
        "한 상품이 여러 카테고리에 속하면 각각에 집계되므로 카테고리 간 합계는 의미가 없습니다."
    )
    st.info(
        "Home/Eco-Friendly/에는 Eco Tee 계열(Google Eco Tee Black, Google Unisex Pride Eco-Tee Black, "
        "Google Women's Eco Tee Black)이 포함되어 있습니다. 이 상품들은 구매 이벤트의 이름 표기가 "
        "달라 연결되지 않았을 가능성이 있어, 이 카테고리의 구매 유저는 과소 집계되었을 수 있습니다."
    )
    st.dataframe(
        category_df[
            [
                "item_category",
                "view_users",
                "cart_users",
                "purchase_users",
                "view_to_cart_pct",
                "cart_to_purchase_pct",
                "overall_conversion_pct",
                "비고",
            ]
        ],
        use_container_width=True,
        hide_index=True,
    )

    st.divider()

    # (c) 상품 매출 Pareto와 매출 vs 수량 순위
    st.header("상품 매출 Pareto와 매출 vs 수량 순위")
    pareto_df = load_csv("item_pareto.csv")
    groups_df = load_csv("item_pareto_groups.csv").set_index("product_group")

    col1, col2, col3 = st.columns(3)
    top10 = groups_df.loc["top_10pct"]
    top20 = groups_df.loc["top_20pct"]
    col1.metric(
        f"상위 10% 상품 ({int(top10['products_in_group'])}개) 매출 비중",
        f"{top10['revenue_share_pct']:.1f}%",
    )
    col2.metric(
        f"상위 20% 상품 ({int(top20['products_in_group'])}개) 매출 비중",
        f"{top20['revenue_share_pct']:.1f}%",
    )
    col3.metric("전체 상품 수", f"{int(top10['total_products'])}개")

    fig_pareto = go.Figure()
    fig_pareto.add_bar(
        x=pareto_df["item_name"],
        y=pareto_df["item_revenue"],
        name="매출",
        marker_color="#4C72B0",
    )
    fig_pareto.add_trace(
        go.Scatter(
            x=pareto_df["item_name"],
            y=pareto_df["cumulative_share_pct"],
            name="누적 매출 비중 (%)",
            mode="lines+markers",
            marker_color="#DD8452",
            yaxis="y2",
        )
    )
    fig_pareto.update_layout(
        title="매출 상위 10개 상품과 누적 매출 비중",
        yaxis=dict(title="item_revenue"),
        yaxis2=dict(title="누적 매출 비중 (%)", overlaying="y", side="right"),
        xaxis=dict(tickangle=-35),
        legend=dict(orientation="h", yanchor="bottom", y=-0.6, xanchor="center", x=0.5),
        height=600,
    )
    st.plotly_chart(fig_pareto, use_container_width=True)

    st.dataframe(
        pareto_df[["revenue_rank", "item_name", "item_revenue", "quantity", "quantity_rank"]],
        use_container_width=True,
        hide_index=True,
    )

    rank_gap_df = load_csv("item_rank_gap.csv")
    rank_gap_df["방향"] = rank_gap_df["rank_gap"].map(
        lambda g: "수량 순위가 매출 순위보다 높음" if g < 0 else "매출 순위가 수량 순위보다 높음"
    )
    fig_gap = px.bar(
        rank_gap_df,
        x="rank_gap",
        y="item_name",
        color="방향",
        orientation="h",
        labels={"rank_gap": "수량 순위 − 매출 순위", "item_name": "상품"},
    )
    fig_gap.update_layout(title="매출 순위와 수량 순위 차이가 큰 상품 5개", yaxis=dict(autorange="reversed"))
    st.plotly_chart(fig_gap, use_container_width=True)

    st.dataframe(
        rank_gap_df[
            ["item_name", "item_revenue", "quantity", "revenue_rank", "quantity_rank", "rank_gap", "revenue_per_unit"]
        ],
        use_container_width=True,
        hide_index=True,
    )
    all_checks_ok = bool(pareto_df["total_check_ok"].all() and rank_gap_df["total_check_ok"].all())
    st.caption(
        "순위는 매출·수량 모두 동률 공동 순위(RANK)이며, 순위 차이는 매출 또는 수량 상위 50위 안의 상품만 "
        "대상으로 했습니다. 매핑 3건은 합산했고, item_revenue 총합 362,110 검증: "
        + ("통과" if all_checks_ok else "불일치")
    )


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
    elif page == "🛍️ 상품 분석":
        render_item_analysis()


if __name__ == "__main__":
    main()

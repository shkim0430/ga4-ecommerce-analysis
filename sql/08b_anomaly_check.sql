-- Q: add_to_cart 누락 기간(2020-11-02~2020-11-15)을 제외한 2020-11-16~2021-01-31만으로 퍼널 교집합을 다시 계산하면, 기존 전체 기간(2020-11-01~2021-01-31) 값과 단계별 전환율이 어떻게 달라지는가? (이벤트 경험 교집합 기준, 세션/시간 순서는 미반영)

WITH user_funnel_flags AS (
  SELECT
    user_pseudo_id,
    MAX(CASE WHEN event_name = 'view_item' THEN 1 ELSE 0 END) AS viewed_full,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS carted_full,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS checkout_full,
    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS purchased_full,
    MAX(CASE WHEN event_name = 'view_item' AND event_date >= '20201116' THEN 1 ELSE 0 END) AS viewed_late,
    MAX(CASE WHEN event_name = 'add_to_cart' AND event_date >= '20201116' THEN 1 ELSE 0 END) AS carted_late,
    MAX(CASE WHEN event_name = 'begin_checkout' AND event_date >= '20201116' THEN 1 ELSE 0 END) AS checkout_late,
    MAX(CASE WHEN event_name = 'purchase' AND event_date >= '20201116' THEN 1 ELSE 0 END) AS purchased_late
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  GROUP BY user_pseudo_id
),

funnel_steps AS (
  SELECT
    '1_view_item' AS step,
    COUNTIF(viewed_full = 1) AS users_full,
    COUNTIF(viewed_late = 1) AS users_from_1116
  FROM user_funnel_flags
  UNION ALL
  SELECT
    '2_add_to_cart' AS step,
    COUNTIF(viewed_full = 1 AND carted_full = 1) AS users_full,
    COUNTIF(viewed_late = 1 AND carted_late = 1) AS users_from_1116
  FROM user_funnel_flags
  UNION ALL
  SELECT
    '3_begin_checkout' AS step,
    COUNTIF(viewed_full = 1 AND carted_full = 1 AND checkout_full = 1) AS users_full,
    COUNTIF(viewed_late = 1 AND carted_late = 1 AND checkout_late = 1) AS users_from_1116
  FROM user_funnel_flags
  UNION ALL
  SELECT
    '4_purchase' AS step,
    COUNTIF(viewed_full = 1 AND carted_full = 1 AND checkout_full = 1 AND purchased_full = 1) AS users_full,
    COUNTIF(viewed_late = 1 AND carted_late = 1 AND checkout_late = 1 AND purchased_late = 1) AS users_from_1116
  FROM user_funnel_flags
)

SELECT
  step,
  users_full,
  users_from_1116,
  SAFE_DIVIDE(users_full, LAG(users_full) OVER (ORDER BY step)) * 100 AS step_pct_full,
  SAFE_DIVIDE(users_from_1116, LAG(users_from_1116) OVER (ORDER BY step)) * 100 AS step_pct_from_1116,
  SAFE_DIVIDE(users_full, FIRST_VALUE(users_full) OVER (ORDER BY step)) * 100 AS overall_pct_full,
  SAFE_DIVIDE(users_from_1116, FIRST_VALUE(users_from_1116) OVER (ORDER BY step)) * 100 AS overall_pct_from_1116
FROM funnel_steps
ORDER BY step;

-- =========

-- Q: 세그먼트에서 purchase_revenue 합이 NULL인 유저(transaction_id가 있는 purchase 기준) 중, NULL 구매가 2021-01-26 이후에 발생한 비율은?

WITH purchase_events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_dt,
    ecommerce.purchase_revenue AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
),

user_revenue AS (
  SELECT
    user_pseudo_id,
    SUM(revenue) AS revenue
  FROM purchase_events
  GROUP BY user_pseudo_id
),

null_revenue_users AS (
  SELECT user_pseudo_id
  FROM user_revenue
  WHERE revenue IS NULL
),

null_user_events AS (
  SELECT
    e.user_pseudo_id,
    COUNT(*) AS null_events,
    COUNTIF(e.event_dt >= DATE '2021-01-26') AS null_events_after_0126
  FROM purchase_events AS e
  INNER JOIN null_revenue_users AS n
    ON e.user_pseudo_id = n.user_pseudo_id
  WHERE e.revenue IS NULL
  GROUP BY e.user_pseudo_id
)

SELECT
  COUNT(*) AS null_revenue_users,
  SUM(null_events) AS null_purchase_events,
  SUM(null_events_after_0126) AS null_events_after_0126,
  SAFE_DIVIDE(SUM(null_events_after_0126), SUM(null_events)) * 100 AS null_events_after_0126_pct,
  COUNTIF(null_events_after_0126 = null_events) AS users_all_after_0126,
  COUNTIF(null_events_after_0126 > 0) AS users_any_after_0126,
  SAFE_DIVIDE(COUNTIF(null_events_after_0126 = null_events), COUNT(*)) * 100 AS users_all_after_0126_pct,
  SAFE_DIVIDE(COUNTIF(null_events_after_0126 > 0), COUNT(*)) * 100 AS users_any_after_0126_pct
FROM null_user_events;

-- =========

-- Q: transaction_id가 없는 purchase 이벤트는 몇 건이고, 주(WEEK(MONDAY))별로 어떻게 분포하는가? (week_start가 NULL인 행은 전체 합계, 부분 주 2020-10-26 포함)

WITH purchase_events AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    ecommerce.transaction_id IS NULL AS no_txn,
    ecommerce.purchase_revenue AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)

SELECT
  week_start,
  COUNT(*) AS all_purchase_events,
  COUNTIF(no_txn) AS no_txn_events,
  SAFE_DIVIDE(COUNTIF(no_txn), COUNT(*)) * 100 AS no_txn_pct,
  COUNTIF(no_txn AND revenue IS NOT NULL) AS no_txn_events_with_revenue,
  SUM(IF(no_txn, revenue, 0)) AS no_txn_revenue
FROM purchase_events
GROUP BY ROLLUP(week_start)
ORDER BY week_start;

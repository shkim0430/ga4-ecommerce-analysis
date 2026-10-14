-- Q: 상품 조회 → 장바구니 → 체크아웃 → 구매 단계를 "모두 순차적으로" 경험한 유저 수와 단계별 전환율은? (이벤트 경험 교집합 기준, 세션/시간 순서는 미반영)

WITH user_funnel_flags AS (
  SELECT
    user_pseudo_id,
    MAX(CASE WHEN event_name = 'view_item' THEN 1 ELSE 0 END) AS viewed_item,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS added_to_cart,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS began_checkout,
    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS purchased
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  GROUP BY user_pseudo_id
),

funnel_steps AS (
  SELECT
    '1_view_item' AS step,
    COUNTIF(viewed_item = 1) AS users
  FROM user_funnel_flags
  UNION ALL
  SELECT
    '2_add_to_cart' AS step,
    COUNTIF(viewed_item = 1 AND added_to_cart = 1) AS users
  FROM user_funnel_flags
  UNION ALL
  SELECT
    '3_begin_checkout' AS step,
    COUNTIF(viewed_item = 1 AND added_to_cart = 1 AND began_checkout = 1) AS users
  FROM user_funnel_flags
  UNION ALL
  SELECT
    '4_purchase' AS step,
    COUNTIF(viewed_item = 1 AND added_to_cart = 1 AND began_checkout = 1 AND purchased = 1) AS users
  FROM user_funnel_flags
)

SELECT
  step,
  users,
  SAFE_DIVIDE(users, LAG(users) OVER (ORDER BY step)) * 100 AS step_conversion_pct,
  SAFE_DIVIDE(users, FIRST_VALUE(users) OVER (ORDER BY step)) * 100 AS overall_conversion_pct
FROM funnel_steps
ORDER BY step;

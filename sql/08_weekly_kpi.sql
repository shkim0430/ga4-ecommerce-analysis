-- Q: 완전한 주(2020-11-02 ~ 2021-01-25 시작, 13주)별 방문자, 조회·장바구니·구매 유저 수, 구매 전환율, 매출은? (제외 규칙: 주 기준은 WEEK(MONDAY)이며 2020-10-26 주는 11/1(일) 하루만 데이터에 있어 제외, 2021-01-25 주는 1/25~1/31 7일이 모두 범위 안이라 포함, 매출은 transaction_id가 있는 purchase 이벤트의 ecommerce.purchase_revenue 합으로 UNNEST 없이 이벤트 단위, purchase_users는 주 단위 distinct라 주별 합산 불가)

WITH events_with_week AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    event_name,
    IF(
      event_name = 'purchase' AND ecommerce.transaction_id IS NOT NULL,
      ecommerce.purchase_revenue,
      NULL
    ) AS txn_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

weekly AS (
  SELECT
    week_start,
    COUNT(DISTINCT user_pseudo_id) AS visitors,
    COUNT(DISTINCT IF(event_name = 'view_item', user_pseudo_id, NULL)) AS view_item_users,
    COUNT(DISTINCT IF(event_name = 'add_to_cart', user_pseudo_id, NULL)) AS add_to_cart_users,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS purchase_users,
    SUM(txn_revenue) AS revenue
  FROM events_with_week
  WHERE week_start BETWEEN DATE '2020-11-02' AND DATE '2021-01-25'
  GROUP BY week_start
)

SELECT
  week_start,
  visitors,
  view_item_users,
  add_to_cart_users,
  purchase_users,
  SAFE_DIVIDE(purchase_users, visitors) * 100 AS conversion_pct,
  COALESCE(revenue, 0) AS revenue
FROM weekly
ORDER BY week_start;

-- =========

-- Q: 완전한 주(2020-11-02 ~ 2021-01-25 시작, 13주)별 item_revenue 상위 5개 상품은? (주간 상품 매출은 표기 차이 미보정: Longsleeve Charcoal/Ash, Womens Google Striped LS는 이름 정규화 없이 그대로 집계, purchase 이벤트만 사용, 조인 없음, 부분 주 제외 규칙은 쿼리 1과 동일, 동률이면 공동 순위)

WITH purchase_items AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    item.item_name AS item_name,
    item.item_revenue AS item_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
),

weekly_items AS (
  SELECT
    week_start,
    item_name,
    SUM(item_revenue) AS item_revenue
  FROM purchase_items
  WHERE week_start BETWEEN DATE '2020-11-02' AND DATE '2021-01-25'
  GROUP BY week_start, item_name
),

ranked AS (
  SELECT
    week_start,
    item_name,
    item_revenue,
    RANK() OVER (PARTITION BY week_start ORDER BY item_revenue DESC) AS rank_in_week
  FROM weekly_items
)

SELECT
  week_start,
  item_name,
  item_revenue,
  rank_in_week
FROM ranked
WHERE rank_in_week <= 5
ORDER BY week_start, rank_in_week, item_name;

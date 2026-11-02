-- Q: 상품(item_name)별로 조회 → 장바구니 → 구매를 모두 경험한 유저 수와 단계별 전환율은? (이벤트 경험 교집합 기준, 조회 유저 100명 이상 + 장바구니 유저 500명 이상 상품만, 구매 유저 30명 미만은 low_sample)

WITH user_item_events AS (
  SELECT DISTINCT
    user_pseudo_id,
    event_name,
    CASE item.item_name
      WHEN 'Google F/C Longsleeve Charcoal' THEN 'Google F/C Long Sleeve Tee Charcoal'
      WHEN 'Google F/C Longsleeve Ash' THEN 'Google F/C Long Sleeve Tee Ash'
      WHEN 'Womens Google Striped LS' THEN "Google Women's Striped L/S"
      ELSE item.item_name
    END AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
    AND item.item_name IS NOT NULL
),

user_item_flags AS (
  SELECT
    user_pseudo_id,
    item_name,
    LOGICAL_OR(event_name = 'view_item') AS viewed,
    LOGICAL_OR(event_name = 'add_to_cart') AS carted,
    LOGICAL_OR(event_name = 'purchase') AS purchased
  FROM user_item_events
  GROUP BY user_pseudo_id, item_name
),

item_funnel AS (
  SELECT
    item_name,
    COUNTIF(viewed) AS view_users,
    COUNTIF(viewed AND carted) AS cart_users,
    COUNTIF(viewed AND carted AND purchased) AS purchase_users
  FROM user_item_flags
  GROUP BY item_name
)

SELECT
  item_name,
  view_users,
  cart_users,
  purchase_users,
  SAFE_DIVIDE(cart_users, view_users) * 100 AS view_to_cart_pct,
  SAFE_DIVIDE(purchase_users, cart_users) * 100 AS cart_to_purchase_pct,
  SAFE_DIVIDE(purchase_users, view_users) * 100 AS overall_conversion_pct,
  purchase_users < 30 AS low_sample
FROM item_funnel
WHERE view_users >= 100
  AND cart_users >= 500
ORDER BY view_users DESC;

-- =========

-- Q: 카테고리(item_category)별로 조회 → 장바구니 → 구매를 모두 경험한 유저 수와 단계별 전환율은? (구매 이벤트의 item_category는 형식이 달라 item_name으로 조회/장바구니 쪽 경로형 분류에 연결, 한 상품이 여러 카테고리에 속하면 각각에 집계, 하위 카테고리가 없는 리프 카테고리만, 조회 유저 100명 이상 카테고리만)

WITH user_item_events AS (
  SELECT DISTINCT
    user_pseudo_id,
    event_name,
    CASE item.item_name
      WHEN 'Google F/C Longsleeve Charcoal' THEN 'Google F/C Long Sleeve Tee Charcoal'
      WHEN 'Google F/C Longsleeve Ash' THEN 'Google F/C Long Sleeve Tee Ash'
      WHEN 'Womens Google Striped LS' THEN "Google Women's Striped L/S"
      ELSE item.item_name
    END AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
    AND item.item_name IS NOT NULL
),

user_item_flags AS (
  SELECT
    user_pseudo_id,
    item_name,
    LOGICAL_OR(event_name = 'view_item') AS viewed,
    LOGICAL_OR(event_name = 'add_to_cart') AS carted,
    LOGICAL_OR(event_name = 'purchase') AS purchased
  FROM user_item_events
  GROUP BY user_pseudo_id, item_name
),

item_category_map AS (
  SELECT DISTINCT
    item.item_name AS item_name,
    item.item_category AS item_category
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart')
    AND item.item_name IS NOT NULL
    AND item.item_category LIKE '%/'
),

all_categories AS (
  SELECT DISTINCT item_category
  FROM item_category_map
),

leaf_categories AS (
  SELECT a.item_category
  FROM all_categories AS a
  LEFT JOIN all_categories AS child
    ON STARTS_WITH(child.item_category, a.item_category)
    AND child.item_category != a.item_category
  GROUP BY a.item_category
  HAVING COUNT(child.item_category) = 0
),

leaf_category_map AS (
  SELECT
    m.item_name,
    m.item_category
  FROM item_category_map AS m
  INNER JOIN leaf_categories AS l
    ON m.item_category = l.item_category
),

user_category_flags AS (
  SELECT
    f.user_pseudo_id,
    m.item_category,
    LOGICAL_OR(f.viewed) AS viewed,
    LOGICAL_OR(f.carted) AS carted,
    LOGICAL_OR(f.purchased) AS purchased
  FROM user_item_flags AS f
  INNER JOIN leaf_category_map AS m
    ON f.item_name = m.item_name
  GROUP BY f.user_pseudo_id, m.item_category
),

category_funnel AS (
  SELECT
    item_category,
    COUNTIF(viewed) AS view_users,
    COUNTIF(viewed AND carted) AS cart_users,
    COUNTIF(viewed AND carted AND purchased) AS purchase_users
  FROM user_category_flags
  GROUP BY item_category
)

SELECT
  item_category,
  view_users,
  cart_users,
  purchase_users,
  SAFE_DIVIDE(cart_users, view_users) * 100 AS view_to_cart_pct,
  SAFE_DIVIDE(purchase_users, cart_users) * 100 AS cart_to_purchase_pct,
  SAFE_DIVIDE(purchase_users, view_users) * 100 AS overall_conversion_pct
FROM category_funnel
WHERE view_users >= 100
ORDER BY view_users DESC;

-- Q: purchase에는 있고 view_item/add_to_cart에는 없는 item_name은 무엇이며, item_revenue 합과 구매 유저 수는?

WITH browse_names AS (
  SELECT DISTINCT item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart')
    AND item.item_name IS NOT NULL
),

purchase_items AS (
  SELECT
    user_pseudo_id,
    item.item_name AS item_name,
    item.item_revenue AS item_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
)

SELECT
  p.item_name,
  SUM(p.item_revenue) AS item_revenue,
  COUNT(DISTINCT p.user_pseudo_id) AS purchase_users
FROM purchase_items AS p
LEFT JOIN browse_names AS b
  ON p.item_name = b.item_name
WHERE b.item_name IS NULL
GROUP BY p.item_name
ORDER BY item_revenue DESC;

-- =========

-- Q: view_item/add_to_cart에는 있고 purchase에는 없는 item_name 중 장바구니(add_to_cart) 유저 500명 이상인 것은?

WITH purchase_names AS (
  SELECT DISTINCT item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
),

browse_users AS (
  SELECT
    item.item_name AS item_name,
    COUNT(DISTINCT IF(event_name = 'view_item', user_pseudo_id, NULL)) AS view_users,
    COUNT(DISTINCT IF(event_name = 'add_to_cart', user_pseudo_id, NULL)) AS cart_users
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart')
    AND item.item_name IS NOT NULL
  GROUP BY item.item_name
)

SELECT
  b.item_name,
  b.view_users,
  b.cart_users
FROM browse_users AS b
LEFT JOIN purchase_names AS p
  ON b.item_name = p.item_name
WHERE p.item_name IS NULL
  AND b.cart_users >= 500
ORDER BY b.cart_users DESC;

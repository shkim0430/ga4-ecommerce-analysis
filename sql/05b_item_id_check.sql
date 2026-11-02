-- Q: view_item/add_to_cart/purchase 이벤트별 item_id 형식 분포는? (GGOE 접두사 / 숫자만 / 그 외 / NULL 비율)

WITH exploded_items AS (
  SELECT
    event_name,
    item.item_id AS item_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
),

classified AS (
  SELECT
    event_name,
    CASE
      WHEN item_id IS NULL THEN 'null'
      WHEN STARTS_WITH(item_id, 'GGOE') THEN 'GGOE_prefix'
      WHEN REGEXP_CONTAINS(item_id, r'^[0-9]+$') THEN 'numeric_only'
      ELSE 'other'
    END AS id_format
  FROM exploded_items
)

SELECT
  event_name,
  id_format,
  COUNT(*) AS item_rows,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY event_name)) * 100 AS share_pct
FROM classified
GROUP BY event_name, id_format
ORDER BY event_name, item_rows DESC;

-- =========

-- Q: view_item ∩ add_to_cart, add_to_cart ∩ purchase, view_item ∩ purchase 사이에서 공통으로 등장하는 distinct item_id는 몇 개인가?

WITH exploded_items AS (
  SELECT
    event_name,
    item.item_id AS item_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
),

item_flags AS (
  SELECT
    item_id,
    LOGICAL_OR(event_name = 'view_item') AS in_view_item,
    LOGICAL_OR(event_name = 'add_to_cart') AS in_add_to_cart,
    LOGICAL_OR(event_name = 'purchase') AS in_purchase
  FROM exploded_items
  WHERE item_id IS NOT NULL
  GROUP BY item_id
)

SELECT
  COUNTIF(in_view_item) AS view_item_ids,
  COUNTIF(in_add_to_cart) AS add_to_cart_ids,
  COUNTIF(in_purchase) AS purchase_ids,
  COUNTIF(in_view_item AND in_add_to_cart) AS view_item_and_add_to_cart,
  COUNTIF(in_add_to_cart AND in_purchase) AS add_to_cart_and_purchase,
  COUNTIF(in_view_item AND in_purchase) AS view_item_and_purchase
FROM item_flags;

-- =========

-- Q: 같은 item_name인데 view_item과 purchase에서 item_id가 서로 겹치지 않는 사례 상위 10개는? (구매 건수 기준)

WITH exploded_items AS (
  SELECT
    event_name,
    item.item_id AS item_id,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'purchase')
),

name_ids AS (
  SELECT
    item_name,
    ARRAY_AGG(DISTINCT IF(event_name = 'view_item', item_id, NULL) IGNORE NULLS) AS view_item_ids,
    ARRAY_AGG(DISTINCT IF(event_name = 'purchase', item_id, NULL) IGNORE NULLS) AS purchase_item_ids,
    COUNTIF(event_name = 'purchase') AS purchase_rows
  FROM exploded_items
  WHERE item_name IS NOT NULL
  GROUP BY item_name
)

SELECT
  item_name,
  ARRAY_TO_STRING(view_item_ids, ', ') AS view_item_ids,
  ARRAY_TO_STRING(purchase_item_ids, ', ') AS purchase_item_ids,
  purchase_rows
FROM name_ids
WHERE ARRAY_LENGTH(view_item_ids) > 0
  AND ARRAY_LENGTH(purchase_item_ids) > 0
  AND NOT EXISTS (
    SELECT 1
    FROM UNNEST(view_item_ids) AS v
    WHERE v IN UNNEST(purchase_item_ids)
  )
ORDER BY purchase_rows DESC
LIMIT 10;

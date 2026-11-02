-- Q: item_name은 GGOE/숫자 중 하나의 item_id 형식에만 걸치는가? 이벤트별 distinct item_name 수와 세 이벤트 모두에 등장하는 item_name 수는?

WITH exploded_items AS (
  SELECT
    event_name,
    item.item_id AS item_id,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
),

classified AS (
  SELECT
    event_name,
    item_name,
    CASE
      WHEN item_id IS NULL THEN 'null'
      WHEN STARTS_WITH(item_id, 'GGOE') THEN 'GGOE_prefix'
      WHEN REGEXP_CONTAINS(item_id, r'^[0-9]+$') THEN 'numeric_only'
      ELSE 'other'
    END AS id_format
  FROM exploded_items
  WHERE item_name IS NOT NULL
),

name_flags AS (
  SELECT
    item_name,
    LOGICAL_OR(event_name = 'view_item') AS in_view_item,
    LOGICAL_OR(event_name = 'add_to_cart') AS in_add_to_cart,
    LOGICAL_OR(event_name = 'purchase') AS in_purchase,
    LOGICAL_OR(id_format = 'GGOE_prefix') AS has_ggoe,
    LOGICAL_OR(id_format = 'numeric_only') AS has_numeric,
    LOGICAL_OR(id_format = 'other') AS has_other
  FROM classified
  GROUP BY item_name
)

SELECT
  COUNT(*) AS distinct_item_names,
  COUNTIF(in_view_item) AS view_item_names,
  COUNTIF(in_add_to_cart) AS add_to_cart_names,
  COUNTIF(in_purchase) AS purchase_names,
  COUNTIF(in_view_item AND in_add_to_cart AND in_purchase) AS all_three_names,
  COUNTIF(has_ggoe AND NOT has_numeric AND NOT has_other) AS ggoe_only_names,
  COUNTIF(has_numeric AND NOT has_ggoe AND NOT has_other) AS numeric_only_names,
  COUNTIF(has_other AND NOT has_ggoe AND NOT has_numeric) AS other_only_names,
  COUNTIF(CAST(has_ggoe AS INT64) + CAST(has_numeric AS INT64) + CAST(has_other AS INT64) > 1) AS multi_format_names
FROM name_flags;

-- =========

-- Q: 하나의 item_id가 여러 item_name을 가지는 사례는 몇 개인가? (item_id 키 충돌 점검)

WITH exploded_items AS (
  SELECT
    item.item_id AS item_id,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
),

id_names AS (
  SELECT
    item_id,
    COUNT(DISTINCT item_name) AS name_count
  FROM exploded_items
  WHERE item_id IS NOT NULL
    AND item_name IS NOT NULL
  GROUP BY item_id
)

SELECT
  COUNT(*) AS distinct_item_ids,
  COUNTIF(name_count > 1) AS ids_with_multiple_names,
  SAFE_DIVIDE(COUNTIF(name_count > 1), COUNT(*)) * 100 AS ids_with_multiple_names_pct,
  MAX(name_count) AS max_names_per_id
FROM id_names;

-- =========

-- Q: purchase에서 SUM(item_revenue)와 SUM(ecommerce.purchase_revenue)는 일치하는가? (UNNEST 중복 집계 점검, 총합과 purchase 이벤트 수 포함)

WITH event_level AS (
  SELECT
    COUNT(*) AS purchase_events,
    SUM(ecommerce.purchase_revenue) AS total_purchase_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

item_level AS (
  SELECT
    COUNT(*) AS item_rows,
    SUM(item.item_revenue) AS total_item_revenue,
    SUM(ecommerce.purchase_revenue) AS naive_unnest_purchase_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)

SELECT
  e.purchase_events,
  i.item_rows,
  e.total_purchase_revenue,
  i.total_item_revenue,
  i.naive_unnest_purchase_revenue,
  SAFE_DIVIDE(i.total_item_revenue, e.total_purchase_revenue) AS item_to_event_revenue_ratio,
  SAFE_DIVIDE(i.naive_unnest_purchase_revenue, e.total_purchase_revenue) AS naive_unnest_inflation_ratio
FROM event_level AS e
CROSS JOIN item_level AS i;

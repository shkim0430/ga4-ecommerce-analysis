-- Q: view_item/add_to_cart/purchase 이벤트별 전체 이벤트 수와 items 배열이 비어있는 이벤트 비율은?

WITH events_with_item_count AS (
  SELECT
    event_name,
    ARRAY_LENGTH(items) AS item_count
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
)

SELECT
  event_name,
  COUNT(*) AS total_events,
  COUNTIF(item_count = 0) AS empty_items_events,
  SAFE_DIVIDE(COUNTIF(item_count = 0), COUNT(*)) * 100 AS empty_items_pct
FROM events_with_item_count
GROUP BY event_name
ORDER BY total_events DESC;

-- =========

-- Q: view_item/add_to_cart/purchase 이벤트별 distinct item_id 수는?

WITH exploded_items AS (
  SELECT
    event_name,
    item.item_id AS item_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
)

SELECT
  event_name,
  COUNT(DISTINCT item_id) AS distinct_item_count
FROM exploded_items
GROUP BY event_name
ORDER BY distinct_item_count DESC;

-- =========

-- Q: item_category 상위 10개는 무엇이며, (not set) 비율은 얼마인가? (UNNEST 후 이벤트 기준)

WITH exploded_items AS (
  SELECT
    item.item_category AS item_category
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'purchase')
),

category_counts AS (
  SELECT
    item_category,
    COUNT(*) AS event_count
  FROM exploded_items
  GROUP BY item_category
),

totals AS (
  SELECT SUM(event_count) AS total_count FROM category_counts
),

ranked_categories AS (
  SELECT
    c.item_category,
    c.event_count,
    SAFE_DIVIDE(c.event_count, t.total_count) * 100 AS share_pct,
    RANK() OVER (ORDER BY c.event_count DESC) AS rnk
  FROM category_counts AS c
  CROSS JOIN totals AS t
)

SELECT
  item_category,
  event_count,
  share_pct
FROM ranked_categories
WHERE rnk <= 10 OR item_category = '(not set)'
ORDER BY event_count DESC;

-- =========

-- Q: item_id별 view_item 이벤트 수 상위 20개는? (item_name 포함)

WITH view_item_events AS (
  SELECT
    item.item_id AS item_id,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'view_item'
)

SELECT
  item_id,
  ANY_VALUE(item_name) AS item_name,
  COUNT(*) AS view_item_count
FROM view_item_events
GROUP BY item_id
ORDER BY view_item_count DESC
LIMIT 20;

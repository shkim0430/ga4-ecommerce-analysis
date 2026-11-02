-- Q: 장바구니→구매 하위 10개 상품의 item_name과 purchase 이벤트에서 이름이 비슷한 항목은? (소문자·공백 제거 후 앞 15자 일치, 두 이름 나란히)

WITH target_items AS (
  SELECT item_name
  FROM UNNEST([
    "Google F/C Long Sleeve Tee Charcoal",
    "Google Women's Striped L/S",
    "Google F/C Long Sleeve Tee Ash",
    "Google Eco Tee Black",
    "Google Land & Sea Unisex Tee",
    "Google Black Tee",
    "Google Pocket Tee Grey",
    "Google Cloud  Unisex Zip Hoodie",
    "Google Unisex Pride Eco-Tee Black",
    "Google Women's Eco Tee Black"
  ]) AS item_name
),

purchase_names AS (
  SELECT
    item.item_name AS item_name,
    COUNT(*) AS purchase_rows
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
  GROUP BY item.item_name
),

target_keys AS (
  SELECT
    item_name,
    SUBSTR(LOWER(REGEXP_REPLACE(item_name, r'\s+', '')), 1, 15) AS name_key
  FROM target_items
),

purchase_keys AS (
  SELECT
    item_name,
    purchase_rows,
    SUBSTR(LOWER(REGEXP_REPLACE(item_name, r'\s+', '')), 1, 15) AS name_key
  FROM purchase_names
)

SELECT
  t.item_name AS target_item_name,
  p.item_name AS purchase_item_name,
  p.purchase_rows,
  t.item_name = p.item_name AS is_exact_match
FROM target_keys AS t
INNER JOIN purchase_keys AS p
  ON t.name_key = p.name_key
ORDER BY t.item_name, p.purchase_rows DESC;

-- =========

-- Q: 장바구니→구매 하위 10개 item_name이 purchase 이벤트에 정확히 일치하는 행 수는? (0이면 이름 불일치 확정)

WITH target_items AS (
  SELECT item_name
  FROM UNNEST([
    "Google F/C Long Sleeve Tee Charcoal",
    "Google Women's Striped L/S",
    "Google F/C Long Sleeve Tee Ash",
    "Google Eco Tee Black",
    "Google Land & Sea Unisex Tee",
    "Google Black Tee",
    "Google Pocket Tee Grey",
    "Google Cloud  Unisex Zip Hoodie",
    "Google Unisex Pride Eco-Tee Black",
    "Google Women's Eco Tee Black"
  ]) AS item_name
),

purchase_names AS (
  SELECT
    item.item_name AS item_name,
    COUNT(*) AS purchase_rows
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
  GROUP BY item.item_name
)

SELECT
  t.item_name,
  COALESCE(p.purchase_rows, 0) AS exact_match_purchase_rows
FROM target_items AS t
LEFT JOIN purchase_names AS p
  ON t.item_name = p.item_name
ORDER BY exact_match_purchase_rows, t.item_name;

-- =========

-- Q: purchase에서 item_name이 view_item/add_to_cart 어디에도 없는 이름은 몇 개이고, 그 item_revenue 합은 전체 대비 몇 %인가?

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
    item.item_name AS item_name,
    item.item_revenue AS item_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

purchase_flagged AS (
  SELECT
    p.item_name,
    p.item_revenue,
    b.item_name IS NULL AS not_in_browse
  FROM purchase_items AS p
  LEFT JOIN browse_names AS b
    ON p.item_name = b.item_name
  WHERE p.item_name IS NOT NULL
)

SELECT
  COUNT(DISTINCT IF(not_in_browse, item_name, NULL)) AS names_not_in_browse,
  SUM(IF(not_in_browse, item_revenue, 0)) AS not_in_browse_item_revenue,
  SUM(item_revenue) AS total_item_revenue,
  SAFE_DIVIDE(SUM(IF(not_in_browse, item_revenue, 0)), SUM(item_revenue)) * 100 AS not_in_browse_revenue_pct
FROM purchase_flagged;

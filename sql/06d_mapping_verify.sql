-- Q: 매핑 후보 2건(purchase 이름 ↔ 조회/장바구니 이름)이 같은 item_id를 공유하는가? 공유하는 ID 목록과 건수는?

WITH name_pairs AS (
  SELECT purchase_name, browse_name
  FROM UNNEST([
    STRUCT("Google Unisex Eco Tee Black" AS purchase_name, "Google Eco Tee Black" AS browse_name),
    STRUCT("Unisex Google Pocket Tee Grey" AS purchase_name, "Google Pocket Tee Grey" AS browse_name)
  ])
),

purchase_ids AS (
  SELECT DISTINCT
    item.item_name AS item_name,
    item.item_id AS item_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IN ('Google Unisex Eco Tee Black', 'Unisex Google Pocket Tee Grey')
    AND item.item_id IS NOT NULL
),

browse_ids AS (
  SELECT DISTINCT
    item.item_name AS item_name,
    item.item_id AS item_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart')
    AND item.item_name IN ('Google Eco Tee Black', 'Google Pocket Tee Grey')
    AND item.item_id IS NOT NULL
),

purchase_side AS (
  SELECT
    n.purchase_name,
    ARRAY_AGG(DISTINCT p.item_id) AS purchase_item_ids
  FROM name_pairs AS n
  INNER JOIN purchase_ids AS p
    ON p.item_name = n.purchase_name
  GROUP BY n.purchase_name
),

browse_side AS (
  SELECT
    n.purchase_name,
    ARRAY_AGG(DISTINCT b.item_id) AS browse_item_ids
  FROM name_pairs AS n
  INNER JOIN browse_ids AS b
    ON b.item_name = n.browse_name
  GROUP BY n.purchase_name
),

combined AS (
  SELECT
    n.purchase_name,
    n.browse_name,
    IFNULL(ps.purchase_item_ids, []) AS purchase_item_ids,
    IFNULL(bs.browse_item_ids, []) AS browse_item_ids
  FROM name_pairs AS n
  LEFT JOIN purchase_side AS ps
    ON n.purchase_name = ps.purchase_name
  LEFT JOIN browse_side AS bs
    ON n.purchase_name = bs.purchase_name
)

SELECT
  purchase_name,
  browse_name,
  ARRAY_LENGTH(purchase_item_ids) AS purchase_id_count,
  ARRAY_LENGTH(browse_item_ids) AS browse_id_count,
  ARRAY_LENGTH(ARRAY(
    SELECT x FROM UNNEST(purchase_item_ids) AS x WHERE x IN UNNEST(browse_item_ids)
  )) AS shared_id_count,
  ARRAY_TO_STRING(ARRAY(
    SELECT x FROM UNNEST(purchase_item_ids) AS x WHERE x IN UNNEST(browse_item_ids)
  ), ', ') AS shared_item_ids,
  ARRAY_TO_STRING(purchase_item_ids, ', ') AS purchase_item_ids,
  ARRAY_TO_STRING(browse_item_ids, ', ') AS browse_item_ids
FROM combined
ORDER BY purchase_name;

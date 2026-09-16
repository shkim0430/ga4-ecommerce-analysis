-- Q: 데이터셋의 날짜 범위는? (min/max event_date)
SELECT
  MIN(event_date) AS min_event_date,
  MAX(event_date) AS max_event_date
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';

-- ===================

-- Q: 이벤트 종류별 발생 횟수는? (event_name 기준 TOP 20)
SELECT
  event_name,
  COUNT(*) AS event_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_name
ORDER BY event_count DESC
LIMIT 20;

-- ===================

-- Q: 유니크 방문자 수는 몇 명인가? (user_pseudo_id 기준)
SELECT
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';

-- ===================

-- Q: purchase 이벤트 총 발생 수와 총 매출(ecommerce.purchase_revenue 합)은?
SELECT
  COUNT(*) AS purchase_event_count,
  SUM(ecommerce.purchase_revenue) AS total_purchase_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase';

-- ===================

-- Q: purchase 이벤트의 items 배열 구조는? (상위 5개 상품과 판매 수량)
WITH purchase_items AS (
  SELECT
    item.item_id,
    item.item_name,
    item.quantity
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  item_id,
  item_name,
  SUM(quantity) AS total_quantity
FROM purchase_items
GROUP BY item_id, item_name
ORDER BY total_quantity DESC
LIMIT 5;

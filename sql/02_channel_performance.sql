-- Q: 채널(source/medium)별 세션·구매 성과와 신규 유저 비중은?

WITH first_event AS (
  SELECT
    user_pseudo_id,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp ASC
    ) AS rn
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

user_channel AS (
  SELECT
    user_pseudo_id,
    source,
    medium
  FROM first_event
  WHERE rn = 1
),

user_purchase AS (
  SELECT
    user_pseudo_id,
    COUNT(*) AS purchase_count,
    SUM(ecommerce.purchase_revenue) AS total_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
  GROUP BY user_pseudo_id
)

SELECT
  uc.source,
  uc.medium,
  COUNT(DISTINCT uc.user_pseudo_id) AS users,
  COUNT(DISTINCT up.user_pseudo_id) AS purchasing_users,
  SAFE_DIVIDE(
    COUNT(DISTINCT up.user_pseudo_id),
    COUNT(DISTINCT uc.user_pseudo_id)
  ) * 100 AS purchase_rate_pct,
  SUM(COALESCE(up.total_revenue, 0)) AS total_revenue,
  SAFE_DIVIDE(
    SUM(COALESCE(up.total_revenue, 0)),
    COUNT(DISTINCT uc.user_pseudo_id)
  ) AS arpu,
  SAFE_DIVIDE(
    SUM(COALESCE(up.total_revenue, 0)),
    COUNT(DISTINCT up.user_pseudo_id)
  ) AS arppu
FROM user_channel AS uc
LEFT JOIN user_purchase AS up
  ON uc.user_pseudo_id = up.user_pseudo_id
GROUP BY uc.source, uc.medium
ORDER BY users DESC
LIMIT 20;

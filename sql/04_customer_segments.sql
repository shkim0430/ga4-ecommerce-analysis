-- Q: 상위 N% 유저가 매출의 몇 %를 만드는가? 구매 빈도/금액대별 세그먼트별 매출 기여도는?

WITH user_revenue AS (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT ecommerce.transaction_id) AS purchase_count,
    SUM(ecommerce.purchase_revenue) AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
  GROUP BY user_pseudo_id
),

ranked AS (
  SELECT
    user_pseudo_id,
    revenue,
    PERCENT_RANK() OVER (ORDER BY revenue DESC) AS revenue_percentile
  FROM user_revenue
),

cumulative AS (
  SELECT
    user_pseudo_id,
    revenue,
    revenue_percentile,
    SUM(revenue) OVER () AS total_revenue
  FROM ranked
),

percentile_groups AS (
  SELECT 'top_10pct' AS user_percentile_group, 0.10 AS pct_cutoff UNION ALL
  SELECT 'top_20pct', 0.20 UNION ALL
  SELECT 'top_30pct', 0.30 UNION ALL
  SELECT 'top_50pct', 0.50 UNION ALL
  SELECT 'top_100pct', 1.00
)

SELECT
  g.user_percentile_group,
  COUNT(DISTINCT CASE WHEN c.revenue_percentile <= g.pct_cutoff THEN c.user_pseudo_id END) AS user_count,
  SUM(CASE WHEN c.revenue_percentile <= g.pct_cutoff THEN c.revenue ELSE 0 END) AS revenue,
  SAFE_DIVIDE(
    SUM(CASE WHEN c.revenue_percentile <= g.pct_cutoff THEN c.revenue ELSE 0 END),
    ANY_VALUE(c.total_revenue)
  ) * 100 AS revenue_share_pct
FROM cumulative AS c
CROSS JOIN percentile_groups AS g
GROUP BY g.user_percentile_group, g.pct_cutoff
ORDER BY g.pct_cutoff;

-- =========

WITH user_revenue AS (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT ecommerce.transaction_id) AS purchase_count,
    SUM(ecommerce.purchase_revenue) AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
  GROUP BY user_pseudo_id
),

segmented AS (
  SELECT
    user_pseudo_id,
    revenue,
    CASE
      WHEN purchase_count = 1 THEN '1회'
      WHEN purchase_count = 2 THEN '2회'
      ELSE '3회+'
    END AS frequency_segment,
    CASE
      WHEN COALESCE(revenue, 0) < 50 THEN 'Low'
      WHEN COALESCE(revenue, 0) < 200 THEN 'Mid'
      WHEN COALESCE(revenue, 0) < 500 THEN 'High'
      ELSE 'VIP'
    END AS monetary_segment
  FROM user_revenue
),

totals AS (
  SELECT
    COUNT(*) AS total_users,
    SUM(revenue) AS total_revenue
  FROM user_revenue
)

SELECT
  s.frequency_segment,
  s.monetary_segment,
  COUNT(*) AS users,
  SUM(s.revenue) AS revenue,
  SAFE_DIVIDE(COUNT(*), ANY_VALUE(t.total_users)) * 100 AS user_share_pct,
  SAFE_DIVIDE(SUM(s.revenue), ANY_VALUE(t.total_revenue)) * 100 AS revenue_share_pct
FROM segmented AS s
CROSS JOIN totals AS t
GROUP BY s.frequency_segment, s.monetary_segment
ORDER BY
  CASE s.frequency_segment WHEN '1회' THEN 1 WHEN '2회' THEN 2 ELSE 3 END,
  CASE s.monetary_segment WHEN 'Low' THEN 1 WHEN 'Mid' THEN 2 WHEN 'High' THEN 3 ELSE 4 END;

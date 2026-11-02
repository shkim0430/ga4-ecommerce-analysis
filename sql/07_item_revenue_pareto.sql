-- Q: item_name별 item_revenue 합과 누적 비중, 구매 수량 합과 수량 기준 순위는? (매출·수량 순위 모두 동률 공동 순위) 매출 상위 10개 상품은? (매핑 3건 합산, 총합 362,110 검증 컬럼 포함)

WITH purchase_items AS (
  SELECT
    CASE item.item_name
      WHEN 'Google F/C Longsleeve Charcoal' THEN 'Google F/C Long Sleeve Tee Charcoal'
      WHEN 'Google F/C Longsleeve Ash' THEN 'Google F/C Long Sleeve Tee Ash'
      WHEN 'Womens Google Striped LS' THEN "Google Women's Striped L/S"
      ELSE item.item_name
    END AS item_name,
    item.item_revenue AS item_revenue,
    item.quantity AS quantity
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

product_revenue AS (
  SELECT
    item_name,
    SUM(item_revenue) AS item_revenue,
    SUM(quantity) AS quantity
  FROM purchase_items
  WHERE item_name IS NOT NULL
  GROUP BY item_name
),

totals AS (
  SELECT SUM(item_revenue) AS all_rows_revenue
  FROM purchase_items
),

ranked AS (
  SELECT
    item_name,
    item_revenue,
    quantity,
    RANK() OVER (ORDER BY item_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY quantity DESC) AS quantity_rank,
    SUM(item_revenue) OVER () AS named_total_revenue,
    SUM(item_revenue) OVER (
      ORDER BY item_revenue DESC, item_name
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
  FROM product_revenue
)

SELECT
  r.revenue_rank,
  r.item_name,
  r.item_revenue,
  SAFE_DIVIDE(r.item_revenue, r.named_total_revenue) * 100 AS revenue_share_pct,
  SAFE_DIVIDE(r.cumulative_revenue, r.named_total_revenue) * 100 AS cumulative_share_pct,
  r.quantity,
  r.quantity_rank,
  r.named_total_revenue,
  t.all_rows_revenue,
  ABS(r.named_total_revenue - 362110) < 0.5 AND ABS(t.all_rows_revenue - 362110) < 0.5 AS total_check_ok
FROM ranked AS r
CROSS JOIN totals AS t
WHERE r.revenue_rank <= 10
ORDER BY r.revenue_rank;

-- =========

-- Q: 매출 상위 10%/20% 상품(item_name)이 전체 item_revenue의 몇 %를 차지하는가? (매핑 3건 합산, 총합 362,110 검증 컬럼 포함)

WITH purchase_items AS (
  SELECT
    CASE item.item_name
      WHEN 'Google F/C Longsleeve Charcoal' THEN 'Google F/C Long Sleeve Tee Charcoal'
      WHEN 'Google F/C Longsleeve Ash' THEN 'Google F/C Long Sleeve Tee Ash'
      WHEN 'Womens Google Striped LS' THEN "Google Women's Striped L/S"
      ELSE item.item_name
    END AS item_name,
    item.item_revenue AS item_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

product_revenue AS (
  SELECT
    item_name,
    SUM(item_revenue) AS item_revenue
  FROM purchase_items
  WHERE item_name IS NOT NULL
  GROUP BY item_name
),

totals AS (
  SELECT SUM(item_revenue) AS all_rows_revenue
  FROM purchase_items
),

ranked AS (
  SELECT
    item_name,
    item_revenue,
    ROW_NUMBER() OVER (ORDER BY item_revenue DESC, item_name) AS revenue_rank,
    COUNT(*) OVER () AS total_products,
    SUM(item_revenue) OVER () AS named_total_revenue
  FROM product_revenue
),

product_groups AS (
  SELECT 'top_10pct' AS product_group, 0.10 AS pct_cutoff UNION ALL
  SELECT 'top_20pct', 0.20
)

SELECT
  g.product_group,
  ANY_VALUE(r.total_products) AS total_products,
  COUNTIF(r.revenue_rank <= CEIL(r.total_products * g.pct_cutoff)) AS products_in_group,
  SUM(IF(r.revenue_rank <= CEIL(r.total_products * g.pct_cutoff), r.item_revenue, 0)) AS group_revenue,
  SAFE_DIVIDE(
    SUM(IF(r.revenue_rank <= CEIL(r.total_products * g.pct_cutoff), r.item_revenue, 0)),
    ANY_VALUE(r.named_total_revenue)
  ) * 100 AS revenue_share_pct,
  ANY_VALUE(r.named_total_revenue) AS named_total_revenue,
  ANY_VALUE(t.all_rows_revenue) AS all_rows_revenue,
  ABS(ANY_VALUE(r.named_total_revenue) - 362110) < 0.5
    AND ABS(ANY_VALUE(t.all_rows_revenue) - 362110) < 0.5 AS total_check_ok
FROM ranked AS r
CROSS JOIN product_groups AS g
CROSS JOIN totals AS t
GROUP BY g.product_group, g.pct_cutoff
ORDER BY g.pct_cutoff;

-- =========

-- Q: 매출 순위와 수량 순위가 크게 다른 상품 5개는? (매출 또는 수량 상위 50위 안에 드는 상품 중 순위 차이 절댓값 기준, 매출·수량 순위 모두 동률 공동 순위, 매핑 3건 합산, 총합 362,110 검증 컬럼 포함)

WITH purchase_items AS (
  SELECT
    CASE item.item_name
      WHEN 'Google F/C Longsleeve Charcoal' THEN 'Google F/C Long Sleeve Tee Charcoal'
      WHEN 'Google F/C Longsleeve Ash' THEN 'Google F/C Long Sleeve Tee Ash'
      WHEN 'Womens Google Striped LS' THEN "Google Women's Striped L/S"
      ELSE item.item_name
    END AS item_name,
    item.item_revenue AS item_revenue,
    item.quantity AS quantity
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

product_revenue AS (
  SELECT
    item_name,
    SUM(item_revenue) AS item_revenue,
    SUM(quantity) AS quantity
  FROM purchase_items
  WHERE item_name IS NOT NULL
  GROUP BY item_name
),

totals AS (
  SELECT SUM(item_revenue) AS all_rows_revenue
  FROM purchase_items
),

ranked AS (
  SELECT
    item_name,
    item_revenue,
    quantity,
    RANK() OVER (ORDER BY item_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY quantity DESC) AS quantity_rank,
    SUM(item_revenue) OVER () AS named_total_revenue
  FROM product_revenue
)

SELECT
  r.item_name,
  r.item_revenue,
  r.quantity,
  r.revenue_rank,
  r.quantity_rank,
  r.quantity_rank - r.revenue_rank AS rank_gap,
  SAFE_DIVIDE(r.item_revenue, r.quantity) AS revenue_per_unit,
  ABS(r.named_total_revenue - 362110) < 0.5 AND ABS(t.all_rows_revenue - 362110) < 0.5 AS total_check_ok
FROM ranked AS r
CROSS JOIN totals AS t
WHERE (r.revenue_rank <= 50 OR r.quantity_rank <= 50)
ORDER BY ABS(r.quantity_rank - r.revenue_rank) DESC, r.item_name
LIMIT 5;

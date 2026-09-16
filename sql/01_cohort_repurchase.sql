-- Q: 첫 구매 코호트별 재구매율 (월간/주간)

WITH purchases AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS purchase_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
),

first_purchase AS (
  SELECT
    user_pseudo_id,
    MIN(purchase_date) AS first_purchase_date,
    DATE_TRUNC(MIN(purchase_date), MONTH) AS cohort_month
  FROM purchases
  GROUP BY user_pseudo_id
),

purchases_with_cohort AS (
  SELECT
    p.user_pseudo_id,
    fp.cohort_month,
    DATE_DIFF(DATE_TRUNC(p.purchase_date, MONTH), fp.cohort_month, MONTH) AS months_since_first
  FROM purchases AS p
  JOIN first_purchase AS fp
    ON p.user_pseudo_id = fp.user_pseudo_id
)

SELECT
  cohort_month,
  months_since_first,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM purchases_with_cohort
GROUP BY cohort_month, months_since_first
ORDER BY cohort_month, months_since_first;

-- =========

-- Q: 첫 구매 코호트별 재구매율 (주간, WEEK(MONDAY) 기준)

WITH purchases AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS purchase_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
),

first_purchase AS (
  SELECT
    user_pseudo_id,
    MIN(purchase_date) AS first_purchase_date,
    DATE_TRUNC(MIN(purchase_date), WEEK(MONDAY)) AS cohort_week
  FROM purchases
  GROUP BY user_pseudo_id
),

purchases_with_cohort AS (
  SELECT
    p.user_pseudo_id,
    fp.cohort_week,
    DATE_DIFF(DATE_TRUNC(p.purchase_date, WEEK(MONDAY)), fp.cohort_week, WEEK(MONDAY)) AS weeks_since_first
  FROM purchases AS p
  JOIN first_purchase AS fp
    ON p.user_pseudo_id = fp.user_pseudo_id
)

SELECT
  cohort_week,
  weeks_since_first,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM purchases_with_cohort
GROUP BY cohort_week, weeks_since_first
ORDER BY cohort_week, weeks_since_first;

-- 후처리 방법: 재구매율(%) = users[m] / users[m=0] * 100, pandas에서 pivot 후 시각화
-- (cohort_month/cohort_week를 index, months_since_first/weeks_since_first를 column으로 pivot)

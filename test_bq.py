from google.cloud import bigquery

client = bigquery.Client()

query = """
SELECT event_name, COUNT(*) AS cnt
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210103'
GROUP BY event_name
ORDER BY cnt DESC
LIMIT 5
"""

df = client.query(query).to_dataframe()
print(df)

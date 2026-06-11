{{ config(schema='pressure_monitoring') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

WITH clustered AS (
  
  SELECT 
    category,
    DATE(first_seen_date) AS publish_date,
    story_id
  
  FROM {{ ref('stg_story_data') }} -- Need to make a staging table for this

  WHERE first_seen_date >= '2026-01-01'
  QUALIFY ROW_NUMBER() OVER(PARTITION BY story_id ORDER BY first_seen_date DESC) = 1
)

SELECT
    category,
    publish_date,
    COUNT(story_id) AS story_count

FROM clustered
GROUP BY category, publish_date
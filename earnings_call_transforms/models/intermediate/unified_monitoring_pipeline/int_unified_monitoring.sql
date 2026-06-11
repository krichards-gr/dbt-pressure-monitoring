{{ config(schema='social_media_activity_archive') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

-- TODO: What tests do we need on this table?

WITH grouped_data AS (
  SELECT DATE(date_posted) AS date_posted,
  category,
  COUNT(retool_primary_key) AS engagement_count
  
  FROM {{ ref('mart_tagged_records') }}
  
  WHERE date_posted IS NOT NULL
  
  GROUP BY date_posted, category
),

engagement_data AS (
SELECT DISTINCT date_posted,
category,
engagement_count

FROM grouped_data
)

SELECT 
  COALESCE(ed.date_posted, sd.publish_date) AS date,
  COALESCE(sd.category, ed.category) AS category,
  IFNULL(sd.story_count, 0) AS story_count,
  IFNULL(ed.engagement_count, 0) AS engagement_count

FROM {{ ref('int_daily_story_data') }} sd

FULL JOIN engagement_data ed
  ON ed.date_posted = DATE(sd.publish_date) AND LOWER(TRIM(ed.category)) = LOWER(TRIM(sd.category))
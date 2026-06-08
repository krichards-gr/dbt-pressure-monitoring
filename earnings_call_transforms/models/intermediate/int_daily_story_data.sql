{{ config(schema='pressure_monitoring') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

WITH clustered AS (
  
  SELECT 
    scm.cluster_id,
    s.category,
    DATE(s.first_seen_date) AS publish_date,
    scm.story_id
  
  FROM {{ source('zignal_gold', 'story_cluster_mapping') }} scm -- Need to make a staging table for this
  
  INNER JOIN {{ ref('stg_story_data') }} s -- TODO: Might just remove this - it's not doing anything here
    ON scm.story_id = s.story_id
 
  WHERE s.first_seen_date >= '2026-01-01'
  QUALIFY ROW_NUMBER() OVER(PARTITION BY scm.story_id ORDER BY scm.match_confidence DESC) = 1
)

SELECT
    category,
    publish_date,
    COUNT(story_id) AS story_count

FROM clustered
GROUP BY category, publish_date
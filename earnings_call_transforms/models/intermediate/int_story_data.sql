{{ config(schema='pressure_monitoring') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

-- Generate the scaffold dynamically through the present day + 14 day buffer
WITH date_scaffold AS (
  SELECT monitoring_end_date
  FROM UNNEST(
    GENERATE_DATE_ARRAY(
      '2025-01-07', 
      DATE_ADD(CURRENT_DATE(), INTERVAL 14 DAY), 
      INTERVAL 14 DAY
    )
  ) AS monitoring_end_date
),

-- Extract all categories dynamically so empty ones don't vanish
unique_categories AS (
  SELECT DISTINCT corrected_category AS category 
    FROM {{ ref('stg_story_data') }}
  WHERE issue_area IS NOT NULL
),

-- Map every category to every scaffold date
master_grid AS (
  SELECT d.monitoring_end_date, c.category
  FROM date_scaffold d
  CROSS JOIN unique_categories c
),

clustered AS (
  SELECT 
    scm.cluster_id,
    s.issue_area,
    DATE(s.last_seen_date) AS publish_date,
    scm.story_id
  FROM {{ source('zignal_gold', 'story_cluster_mapping') }} scm -- Need to make a staging table for this
  INNER JOIN {{ ref('stg_story_data') }} s
    ON scm.story_id = s.story_id
  WHERE s.last_seen_date >= '2026-01-01'
  QUALIFY ROW_NUMBER() OVER(PARTITION BY scm.story_id ORDER BY scm.match_confidence DESC) = 1
),

cluster_starts AS (
  SELECT 
    cluster_id, 
    ANY_VALUE(issue_area) AS issue_area,
    MIN(publish_date) AS cluster_started_date,
    COUNT(story_id) AS stories_in_cluster
  FROM clustered
  GROUP BY cluster_id
),

-- Aggregate actual story volume into 14-day blocks
actual_counts AS (
  SELECT
    DATE_ADD(DATE('2025-01-07'), INTERVAL CAST(CEIL(DATE_DIFF(cluster_started_date, DATE('2025-01-07'), DAY) / 14) * 14 AS INT64) DAY) AS engagement_period_date,
    issue_area AS category,
    SUM(stories_in_cluster) AS total_story_count
  FROM cluster_starts
  GROUP BY 1, 2
)

-- Step 5: Join actuals to the master grid and cap it at the current period
SELECT
  mg.monitoring_end_date AS engagement_period_date,
  mg.category,
  COALESCE(ac.total_story_count, 0) AS total_story_count
FROM master_grid mg
LEFT JOIN actual_counts ac
  ON mg.monitoring_end_date = ac.engagement_period_date
  AND mg.category = ac.category
WHERE mg.monitoring_end_date >= '2026-01-01'
  -- Prevents the chart from projecting too far into the future 
  AND mg.monitoring_end_date <= DATE_ADD(CURRENT_DATE(), INTERVAL 14 DAY)
ORDER BY engagement_period_date DESC, category ASC
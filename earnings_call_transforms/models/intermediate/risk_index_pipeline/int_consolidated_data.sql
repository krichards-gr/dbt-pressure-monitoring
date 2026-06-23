{{ config(schema='risk_index_data') }}

-- TODO: Aggregate engagement data before joining
WITH consolidated_engagements AS (

    SELECT
        quarter_start,
        category,
        SUM(engagement_count) AS engagement_count,
        SUM(backlash_count) AS backlash_count

    FROM {{ ref('int_engagement_data') }}

GROUP BY quarter_start, category
ORDER BY quarter_start DESC, category
)

SELECT
    ivd.category,
    ivd.quarter_start,
    weekly_average,
    percent_change_vs_rolling_avg,
    inter_issue_score,
    intra_issue_score,
    combined_score,
    engagement_count,
    backlash_count,
    -- Engagement Score
  CASE
    WHEN engagement_count >= 60 THEN 4
    WHEN engagement_count >= 45 THEN 3
    WHEN engagement_count >= 25 THEN 2
    ELSE 1
  END AS engagement_score,

  -- Backlash Score
  CASE
    WHEN backlash_count >= 30 THEN 4
    WHEN backlash_count >= 20 THEN 3
    WHEN backlash_count >= 10 THEN 2
    ELSE 1
  END AS backlash_score

FROM {{ ref('int_volume_data')}} ivd

LEFT JOIN consolidated_engagements ce
    ON TRIM(LOWER(ivd.category)) = TRIM(LOWER(ce.category))
        AND DATE(ivd.quarter_start) = DATE(ce.quarter_start)
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
    backlash_count

FROM {{ ref('int_volume_data')}} ivd

LEFT JOIN consolidated_engagements ce
    ON TRIM(LOWER(ivd.category)) = TRIM(LOWER(ce.category))
        AND DATE(ivd.quarter_start) = DATE(ce.quarter_start)
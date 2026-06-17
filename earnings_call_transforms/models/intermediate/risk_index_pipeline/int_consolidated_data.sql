{{ config(schema='risk_index_data') }}

-- TODO: Aggregate engagement data before joining
SELECT
    ivd.category,
    ivd.quarter_start,
    sector,
    weekly_average,
    percent_change_vs_rolling_avg,
    inter_issue_score,
    intra_issue_score,
    combined_score,
    engagement_count,
    backlash_count

FROM {{ ref('int_volume_data')}} ivd

LEFT JOIN {{ ref('int_engagement_data') }} ied
    ON TRIM(LOWER(ivd.category)) = TRIM(LOWER(ied.category))
        AND DATE(ivd.quarter_start) = DATE(ied.quarter_start)
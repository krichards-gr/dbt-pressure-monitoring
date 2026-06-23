{{ config(schema='risk_index_data') }}

SELECT
    category,
    quarter_start,
    weekly_average,
    percent_change_vs_rolling_avg,
    inter_issue_score,
    intra_issue_score,
    combined_score,
    engagement_count,
    backlash_count,
    engagement_score,
    backlash_score

FROM {{ ref('int_consolidated_data') }}

ORDER BY quarter_start DESC, category
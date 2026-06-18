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
    backlash_count

FROM {{ ref('int_consolidated_data') }}
{{ config(schema='risk_index_data') }}

SELECT 
    category,
    quarter_start,
    weekly_average,
    percent_change_vs_rolling_avg,
    inter_issue_score,
    intra_issue_score,
    combined_score

FROM {{ ref('int_volume_data')}}
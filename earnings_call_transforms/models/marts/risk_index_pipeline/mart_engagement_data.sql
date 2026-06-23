{{ config(schema='risk_index_data') }}

SELECT
    sector,
    category,
    quarter_start,
    engagement_count,
    backlash_count,
    engagement_score,
    backlash_score

FROM {{ ref('int_engagement_data')}}

ORDER BY quarter_start DESC, category
{{
    config(
        schema='risk_index_data',
        materialized = 'table',
        partition_by = {
            "field": "quarter_start",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by = ['category', 'sector']
    )
}}
SELECT
    sector,
    category,
    quarter_start,
    engagement_count,
    backlash_count,
    engagement_score,
    backlash_score

FROM {{ ref('int_engagement_data')}}
{{
    config(
        schema='risk_index_data',
        materialized = 'table',
        partition_by = {
            "field": "quarter_start",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by = ['category']
    )
}}
SELECT
    category,
    quarter_start,
    raw_score,
    normalized_score,
    normalized_score / 10 AS risk_index_score

FROM {{ ref('int_quarterly_risk_metrics') }}
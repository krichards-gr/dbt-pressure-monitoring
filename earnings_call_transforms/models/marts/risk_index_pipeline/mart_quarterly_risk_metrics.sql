{{ config(schema='risk_index_data') }}

SELECT
    category,
    quarter_start,
    raw_score,
    normalized_score,
    normalized_score / 10 AS risk_index_score

FROM {{ ref('int_quarterly_risk_metrics') }}
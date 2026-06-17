{{ config(schema='risk_index_data') }}

SELECT
    sector,
    category,
    quarter_start,
    engagement_count,
    backlash_count

FROM {{ ref('int_engagement_data')}}
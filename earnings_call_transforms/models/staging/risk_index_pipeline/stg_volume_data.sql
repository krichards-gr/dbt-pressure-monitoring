{{ config(schema='risk_index_data', materialized='table') }}

WITH source_data AS (
    SELECT * FROM {{ source('raw_risk_data', 'weekly_mentions_raw') }}
)

SELECT
  triple.dataset_name,
  DATE(COALESCE(
    SAFE.PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', triple.date_str),
    SAFE.PARSE_TIMESTAMP('%m/%d/%Y %H:%M', triple.date_str)
  )) AS date,
  triple.m_count
FROM source_data,
UNNEST([
  STRUCT(dataset_name_1 AS dataset_name, date_1 AS date_str, m_count_1 AS m_count),
  STRUCT(dataset_name_2, date_2, m_count_2),
  STRUCT(dataset_name_3, date_3, m_count_3),
  STRUCT(dataset_name_4, date_4, m_count_4),
  STRUCT(dataset_name_5, date_5, m_count_5),
  STRUCT(dataset_name_6, date_6, m_count_6),
  STRUCT(dataset_name_7, date_7, m_count_7),
  STRUCT(dataset_name_8, date_8, m_count_8),
  STRUCT(dataset_name_9, date_9, m_count_9),
  STRUCT(dataset_name_10, date_10, m_count_10),
  STRUCT(dataset_name_11, date_11, m_count_11),
  STRUCT(dataset_name_12, date_12, m_count_12)
]) AS triple
WHERE triple.dataset_name IS NOT NULL
  AND triple.date_str IS NOT NULL
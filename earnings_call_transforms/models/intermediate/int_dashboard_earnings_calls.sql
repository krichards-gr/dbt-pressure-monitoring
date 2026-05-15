{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='paragraph_id'
) }}

WITH base_calls AS (
  SELECT info.transcript_id,
    info.symbol,
    info.report_date,
    info.fiscal_year,
    info.fiscal_quarter,
    c.paragraph_number,
    c.speaker,
    c.content, -- Explicitly select all columns
    TO_HEX(MD5(CONCAT(c.transcript_id, '_', CAST(paragraph_number AS STRING)))) as paragraph_id
  
  FROM {{ ref('stg_earnings_call_metadata') }} info

  LEFT JOIN {{ ref('stg_earnings_call_content') }} c
    ON info.transcript_id = c.transcript_id
),

-- Apply the incremental filter to the base
source_calls AS (
  SELECT * FROM base_calls
  {% if is_incremental() %}
    WHERE paragraph_id NOT IN (SELECT paragraph_id FROM {{ this }})
  {% endif %}
),

enrichments AS (
  SELECT 
      s.paragraph_id,
      s.symbol,
      s.report_date,
      s.fiscal_year,
      s.fiscal_quarter,
      s.speaker,
      s.content,
      s.transcript_id,
      s.paragraph_number,
      e.speaker_type,
      e.segment_type
  FROM source_calls s  -- Using the filtered source
  LEFT JOIN {{ ref('int_earnings_call_enrichments') }} e
    ON s.transcript_id = e.transcript_id 
    AND s.paragraph_number = e.paragraph_number
)

SELECT 
    en.paragraph_id,
    en.symbol,
    ref.corporation,
    ref.sector,
    en.transcript_id,
    en.report_date,
    en.fiscal_year,
    en.fiscal_quarter,
    en.paragraph_number,
    en.speaker,
    en.speaker_type,
    en.segment_type,
    en.content
FROM enrichments en
LEFT JOIN {{ ref('stg_corporate_reference') }} ref
  ON en.symbol = ref.symbol
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
    c.content,
    -- Generate the ID based on the natural business key grain
    TO_HEX(MD5(CONCAT(c.transcript_id, '_', CAST(c.paragraph_number AS STRING)))) as paragraph_id
  
  FROM {{ ref('stg_earnings_call_metadata') }} info
  LEFT JOIN {{ ref('stg_earnings_call_content') }} c
    ON info.transcript_id = c.transcript_id

  -- If you want to optimize performance for incremental runs, filter by a timestamp here instead
  {% if is_incremental() %}
    WHERE info.report_date >= (SELECT MAX(report_date) FROM {{ this }})
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
  FROM base_calls s
  LEFT JOIN {{ ref('int_earnings_call_enrichments') }} e
    ON s.transcript_id = e.transcript_id 
    AND s.paragraph_number = e.paragraph_number
),

final_joined AS (
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
),

deduped AS (
  SELECT *,
    -- Enforce uniqueness across the final output batch
    ROW_NUMBER() OVER (PARTITION BY paragraph_id ORDER BY report_date DESC) as rn
  FROM final_joined
)

SELECT 
  paragraph_id,
  symbol,
  corporation,
  sector,
  transcript_id,
  report_date,
  fiscal_year,
  fiscal_quarter,
  paragraph_number,
  speaker,
  speaker_type,
  segment_type,
  content
FROM deduped
WHERE rn = 1
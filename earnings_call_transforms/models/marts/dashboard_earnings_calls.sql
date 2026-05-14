{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='paragraph_id'
) }}

WITH base_calls AS (
  SELECT *,
    TO_HEX(MD5(CONCAT(transcript_id, '_', CAST(paragraph_number AS STRING)))) as paragraph_id
  FROM {{ ref('stg_earnings_call_joined') }}
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
  LEFT JOIN {{ ref('earnings_call_transcript_enrichments') }} e
    ON s.transcript_id = e.transcript_id 
    AND s.paragraph_number = e.paragraph_number
)

SELECT 
    en.paragraph_id,
    en.symbol,
    TRIM(ref.corporation) as corporation,
    TRIM(ref.sector) as sector,
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
LEFT JOIN {{ source('social_media_activity_archive', 'benchmarking_corporate_reference') }} ref
  ON en.symbol = ref.Ticker

-- THE MAGIC FIX: Ensures that if 'ref' has duplicates, we only take one per Ticker
QUALIFY ROW_NUMBER() OVER (PARTITION BY en.paragraph_id ORDER BY ref.Rank) = 1
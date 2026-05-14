{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='paragraph_id'
) }}

WITH source_calls AS (
  SELECT *,
    -- Unique paragraph id code
    TO_HEX(MD5(CONCAT(transcript_id, '_', CAST(paragraph_number AS STRING))) as paragraph_id)
  FROM {{ ref('stg_earnings_call_joined') }}

  {% if is_incremental() %}
    WHERE transcript_id NOT IN (
      SELECT DISTINCT transcript_id
      FROM {{ this }}
      WHERE transcript_id IS NOT NULL
    )
  {% endif %}
),

enrichments AS (
SELECT source_calls.paragraph_id,
      source_calls.symbol,
      source_calls.report_date,
      source_calls.fiscal_year,
      source_calls.fiscal_quarter,
      source_calls.speaker,
      source_calls.content,
      source_calls.transcript_id,
      source_calls.paragraph_number,
      enrich.speaker_type,
      enrich.segment_type
FROM source_calls
LEFT JOIN {{ source('pressure_monitoring', 'earnings_call_transcript_enrichments') }} enrich
  ON source_calls.transcript_id = enrich.transcript_id AND source_calls.paragraph_number = enrich.paragraph_number
)

SELECT enrichments.paragraph_id,
      enrichments.symbol,
      TRIM(ref.corporation) as corporation,
      TRIM(ref.sector) as sector,
      enrichments.transcript_id,
      enrichments.report_date,
      enrichments.fiscal_year,
      enrichments.fiscal_quarter,
      enrichments.paragraph_number,
      enrichments.speaker,
      enrichments.speaker_type,
      enrichments.segment_type,
      enrichments.content
FROM enrichments
LEFT JOIN {{ source('social_media_activity_archive', 'benchmarking_corporate_reference') }} ref
  ON enrichments.symbol = ref.Ticker
-- ORDER BY enrichments.report_date DESC, ref.Ticker, enrichments.paragraph_number
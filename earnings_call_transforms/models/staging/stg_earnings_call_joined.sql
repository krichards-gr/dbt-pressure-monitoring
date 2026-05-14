-- Deduplicated (on transcript_id) and get/join records from raw earnings call tables (metadata + content)
-- This table undergirds both the enrichment and dashboarding tables

{{ config(materialized='view') }}

SELECT
  info.transcript_id,
  info.symbol,
  info.report_date,
  info.fiscal_year,
  info.fiscal_quarter,
  c.paragraph_number,
  c.speaker,
  c.content
FROM (
  SELECT *
  FROM {{ source('pressure_monitoring', 'earnings_call_transcript_metadata') }}
  QUALIFY ROW_NUMBER() OVER (PARTITION BY transcript_id ORDER BY report_date DESC) = 1
) info
LEFT JOIN {{ source('pressure_monitoring', 'earnings_call_transcript_content') }} c
  ON info.transcript_id = c.transcript_id

  -- Deduplicate based on unique combinations of transcript_id and paragraph_number
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY info.transcript_id, c.paragraph_number
    ORDER BY c.speaker
  ) = 1
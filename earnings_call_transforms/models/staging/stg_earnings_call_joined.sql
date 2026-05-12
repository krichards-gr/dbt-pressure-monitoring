{{ config(materialized='view') }}

SELECT
  info.transcript_id,
  info.symbol,
  info.report_date,
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
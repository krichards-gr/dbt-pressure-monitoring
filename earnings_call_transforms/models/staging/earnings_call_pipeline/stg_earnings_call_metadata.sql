SELECT
  transcript_id,
  TRIM(UPPER(symbol)) as symbol, -- Enforce uppercase here
  report_date, -- Enforce date here
  fiscal_year, -- Enforce integer here
  fiscal_quarter -- Enforce integer here

  FROM {{ source('pressure_monitoring', 'earnings_call_transcript_metadata') }}

  QUALIFY ROW_NUMBER() OVER (PARTITION BY transcript_id ORDER BY report_date DESC) = 1
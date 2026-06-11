SELECT transcript_id,
    paragraph_number,
    speaker,
    content

FROM {{ source('pressure_monitoring', 'earnings_call_transcript_content') }}

  -- Deduplicate based on unique combinations of transcript_id and paragraph_number
QUALIFY ROW_NUMBER() OVER (
PARTITION BY transcript_id, paragraph_number
ORDER BY speaker
) = 1
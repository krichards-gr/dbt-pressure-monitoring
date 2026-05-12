{{ config(
    materialized='incremental',
    incremental_strategy='merge'
) }}

WITH source_calls AS (
  SELECT *
  FROM {{ ref('stg_earnings_call_joined') }}

  {% if is_incremental() %}
    -- This replaces your IF guard + NOT IN filter.
    -- On incremental runs, only pull transcript_ids
    -- that don't already exist in the target table.
    WHERE transcript_id NOT IN (
      SELECT DISTINCT transcript_id
      FROM {{ this }}
      WHERE transcript_id IS NOT NULL
    )
  {% endif %}
),

qa_tagged AS (
  SELECT *,
    CASE
      WHEN (LOWER(content) LIKE "%first question%" OR LOWER(content) LIKE "%first caller%")
           AND speaker = 'Operator' THEN paragraph_number
      ELSE NULL
    END AS qa_start
  FROM source_calls
),

qa_start_indexed AS (
  SELECT *,
    MIN(qa_start) OVER (PARTITION BY transcript_id) AS qa_start_index,
    MIN(paragraph_number) OVER (PARTITION BY transcript_id, speaker) AS first_appearance
  FROM qa_tagged
),

exec_tagged AS (
  SELECT *,
    CASE
      WHEN first_appearance < qa_start_index AND speaker != "Operator" THEN "Executive"
      WHEN speaker = "Operator" THEN "Operator"
      ELSE "Analyst"
    END AS speaker_type
  FROM qa_start_indexed
),

enriched AS (
  SELECT
    transcript_id,
    paragraph_number,
    speaker_type,
    CASE
      WHEN speaker_type = "Operator" THEN "Administrative"
      WHEN speaker_type = "Analyst" THEN "Question"
      WHEN speaker_type = "Executive" AND paragraph_number <= qa_start_index
        THEN "Administrative"
      ELSE "Answer"
    END AS segment_type
  FROM exec_tagged
)

SELECT
  transcript_id,
  paragraph_number,
  speaker_type,
  segment_type
FROM enriched
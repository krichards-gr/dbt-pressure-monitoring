-- To scale, we'll want this to be incremental (?). Not necessary right now, though
-- What tests do I need to enforce?
{{ config(
    unique_key=['corporation', 'category', 'url'],
    schema='social_media_activity_archive'
) }}

--From the submissions table, grab only the rows that are not yet finalized in the CED AND which need to be split
WITH test_rows AS (
  SELECT submitted_on, corporation, sector, engagement_date, category, engagement_type, engagement_subtype, summary, url
FROM {{ ref('stg_benchmarking_analyst_subs') }}
WHERE completed = false -- I don't believe that this field is actually being utilized by submitters. How are we currently controlling for already-processed records?
AND (
      REGEXP_CONTAINS(corporation, r'[,;]')
      OR REGEXP_CONTAINS(category, r'[,;]')
    )
--   ORDER BY submitted_on DESC
),

--Grab the rest of the rows from the submissions table (i.e., the ones that are not yet finalized in the CED but which DO NOT NEED TO BE SPLIT
other_rows AS (
  SELECT submitted_on, corporation, sector, engagement_date, category, engagement_type, engagement_subtype, summary, url
  FROM {{ ref('stg_benchmarking_analyst_subs') }}
WHERE NOT(
        completed = false -- I don't believe that this field is actually being utilized by submitters. How are we currently controlling for already-processed records?
    AND (
        REGEXP_CONTAINS(corporation, r'[,;]')
        OR REGEXP_CONTAINS(category, r'[,;]')
        )
    )
),

--Operate on the rows that need to be split, first splitting by the corporation column...
corp_split AS (
  SELECT *
  FROM test_rows,
    UNNEST(SPLIT(REPLACE(corporation, ";", ","), ',')) AS new_corporation
),

--...then splitting by the societal issue column
issue_split AS (
  SELECT *
  FROM corp_split,
    UNNEST(SPLIT(REPLACE(category, ";", ","), ',')) AS new_category
),

-- Consolidate split and unsplit records & normalize for ingestion into Retool
combinedAnalystInputs AS (
SELECT * FROM ( -- Do we need this exterior select?
  SELECT TRIM(REPLACE(new_corporation, 'and', '')) AS corporation,
      sector,
      CAST(engagement_date AS TIMESTAMP) AS date_posted,
      CAST(NULL AS STRING) post_text,
      url,
      CAST(NULL AS STRING) AS platform,
      new_category AS category,
      engagement_type,
      engagement_subtype AS `Engagement_Sub-Type`,
      summary

  FROM issue_split A
UNION ALL
SELECT corporation,
      sector,
      CAST(engagement_date AS TIMESTAMP) AS date_posted,
      CAST(NULL AS STRING) post_text,
      url,
      CAST(NULL AS STRING) AS platform,
      category,
      engagement_type,
      engagement_subtype AS `Engagement_Sub-Type`,
      summary

  FROM other_rows
  )
  WHERE DATE(date_posted) >= '2025-12-03' -- TODO: What's going on with this hardcoded date?
),

inputs_w_sector AS (
    SELECT
        'Harrison Firestone' AS assignments,
        A.category,
        A.corporation,
        date_posted,
        CAST(NULL AS TIMESTAMP) as deleted_at,
        CAST(NULL as STRING) as edit_notes,
        'Not Reviewed' AS edit_status,
        A.Engagement_Type,
        A.`Engagement_Sub-Type`,
        CAST(NULL AS STRING) AS event_group_id,
        CAST(NULL AS BOOLEAN) as is_deleted,
        CASE WHEN A.url LIKE '%instagram%' THEN 'Instagram'
          WHEN A.url LIKE '%linkedin%' THEN 'LinkedIn'
          WHEN A.url LIKE '%/x.com%' THEN 'Twitter'
          ELSE 'Other'
        END AS platform,
        A.post_text,
        B.product,
        REPLACE(TRIM(LOWER(COALESCE(A.corporation, ''))), ' ', '_') || '::' || TRIM(LOWER(COALESCE(A.url, ''))) || '::' || REPLACE(TRIM(LOWER(COALESCE(A.category, ''))), ' ', '_') 
          AS retool_primary_key,
        'Analyst Inputs' AS row_status,
        B.sector,
        A.summary,
        A.url
        
    FROM combinedAnalystInputs A -- TODO: This join feels unnecessary, can we drop?
        LEFT JOIN {{ ref('stg_corporate_reference') }} AS B
        ON TRIM(LOWER(B.corporation)) = TRIM(LOWER(A.corporation))
)

SELECT * -- TODO: Explicitly name all columns

FROM inputs_w_sector iws

WHERE (iws.retool_primary_key
      ) NOT IN (
        SELECT retool_primary_key
        FROM {{ ref('int_tagged_records')}}
      )
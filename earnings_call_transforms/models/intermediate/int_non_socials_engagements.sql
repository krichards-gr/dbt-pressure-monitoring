-- TODO: What tests do we need to enforce on this view?
{{ config(schema='non_socials_engagement_data') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

WITH rawCedData AS (
  SELECT
    corporation,
    sector,
    date_posted,
    engagement_type AS Engagement_Type,
    engagement_subtype AS `Engagement_Sub-Type`, -- TODO: Need to handle these clunky field names throughout model
    category,
    publish_date,
    url,
    post_text,
    summary,
    CASE WHEN url LIKE '%instagram%' THEN 'Instagram'
      WHEN url LIKE '%linkedin%' THEN 'LinkedIn'
      WHEN url LIKE '%/x.com%' THEN 'Twitter'
      ELSE 'Other'
    END AS platform,
    CAST(NULL AS STRING) AS event_group_id,
    CAST(NULL AS STRING) AS assignments,
    'Unlabeled' AS row_status,
    REPLACE(TRIM(LOWER(COALESCE(corporation, ''))), ' ', '_') || '::' || TRIM(LOWER(COALESCE(url, ''))) || '::' || REPLACE(TRIM(LOWER(COALESCE(category, ''))), ' ', '_') AS retool_primary_key,
  FROM {{ ref('stg_non_socials_engagements') }}

  WHERE CAST(confidence_assessment AS INT64) >= 80
),
  
cedLabeled as (
  SELECT
    COALESCE(NULLIF(TRIM(B.assignments), ''), 'Unassigned') AS assignments,
    A.category,
    A.corporation,
    A.date_posted,
    CAST(NULL AS TIMESTAMP) as deleted_at,
    CAST(NULL as STRING) as edit_notes,
    'Not Reviewed' as edit_status,
    A.Engagement_Type,
    A.`Engagement_Sub-Type`,
    A.event_group_id,
    CAST(NULL AS BOOLEAN) as is_deleted,
    A.platform,
    A.post_text,
    B.product,
    A.retool_primary_key,
    A.row_status,
    COALESCE(B.sector, A.sector) as sector,
    A.summary,
    A.url,

  FROM rawCedData AS A

  LEFT JOIN {{ ref('stg_corporate_reference') }} AS B
  ON TRIM(LOWER(B.corporation)) = TRIM(LOWER(A.corporation))

    WHERE DATE(A.date_posted) >= '2025-12-01' -- What's with these hard-coded dates?
    OR A.date_posted IS NULL
)

SELECT *

FROM cedLabeled

WHERE retool_primary_key NOT IN ( --- TODO: Swap to NOT EXISTS for safety
        SELECT retool_primary_key
        FROM {{ ref('int_tagged_records')}}
      )
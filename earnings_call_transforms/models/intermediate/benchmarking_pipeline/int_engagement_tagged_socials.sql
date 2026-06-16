{{ config(schema='social_media_activity_archive') }}

-- 1. Dynamically pull historical patterns to determine probabilistic priority
WITH historical_frequencies AS (
  SELECT 
    `Engagement_Sub-Type` AS engagement_sub_type,
    COUNT(*) AS historical_record_count
  FROM `sri-benchmarking-databases.social_media_activity_archive.mart_tagged_records`
  GROUP BY 1
),

-- 2. Build reference table with matched engagement terms
matched_tags AS (
  SELECT 
    its.retool_primary_key,
    et.engagement_sub_type,
    et.engagement_type,
    STRING_AGG(DISTINCT et.key_terms, ', ') AS matched_terms
  
  FROM {{ ref('int_issue_tagged_socials') }} its
  
  INNER JOIN {{ ref('stg_engagement_term_reference') }} et
    ON REGEXP_CONTAINS(its.post_text, et.key_terms)
  
  GROUP BY 1, 2, 3
),

-- 3. Select top engagement label based on historical probability
resolved_and_ranked AS (

  SELECT 
    its.assignments,
    its.category,
    its.corporation,
    its.date_posted,
    its.deleted_at,
    its.edit_notes,
    its.edit_status,
    COALESCE(mt.engagement_type, its.engagement_type) AS engagement_type,
    COALESCE(mt.engagement_sub_type, its.engagement_sub_type) AS engagement_sub_type, 
    mt.matched_terms,
    its.event_group_id,
    its.is_deleted,
    its.platform,
    its.post_text,
    its.product,
    its.retool_primary_key,
    its.row_status,
    its.sector,
    its.summary,
    its.url,
    
    -- Sorts by historical volume DESC. Brand new sub-types default to 0 volume.
    -- Sub-type alphabetical string sort added as a secondary fallback key for deterministic ties.
    ROW_NUMBER() OVER (
      PARTITION BY its.retool_primary_key 
      ORDER BY 
        COALESCE(hf.historical_record_count, 0) DESC,
        COALESCE(mt.engagement_sub_type, its.engagement_sub_type) ASC
    ) AS tag_priority

  FROM {{ ref('int_issue_tagged_socials') }} its
  INNER JOIN matched_tags mt
    ON its.retool_primary_key = mt.retool_primary_key
  LEFT JOIN historical_frequencies hf
    ON COALESCE(mt.engagement_sub_type, its.engagement_sub_type) = hf.engagement_sub_type
)

-- 4. Filter down to only the single highest-probability row per primary key
SELECT
    assignments,
    category,
    corporation,
    date_posted,
    deleted_at,
    edit_notes,
    edit_status,
    engagement_type,
    engagement_sub_type, 
    matched_terms,
    event_group_id,
    is_deleted,
    platform,
    post_text,
    product,
    retool_primary_key,
    row_status,
    sector,
    summary,
    url

FROM resolved_and_ranked

WHERE tag_priority = 1
{{ config(schema='social_media_activity_archive') }}

-- Build reference table with matched engagement terms
WITH matched_tags AS (
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

-- Select top engagement label (based on alphabetical ordering for now) and join with full record set
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
    
    -- Alphabetical ranking system  TODO: Can we build a ranking system that is based on historical pattern performance?
    ROW_NUMBER() OVER (
      PARTITION BY its.retool_primary_key 
      ORDER BY 
        CASE COALESCE(mt.engagement_sub_type, its.engagement_sub_type)
          WHEN 'Advocacy/Lobbying' THEN 1
          WHEN 'Donation/Grant'    THEN 2
          WHEN 'Employee Event'    THEN 3
          WHEN 'Observed Holiday'  THEN 4
          WHEN 'Product Line'      THEN 5
          WHEN 'Sponsorship'       THEN 6
          ELSE 7 -- Catches any other tag not explicitly listed
        END ASC
    ) AS tag_priority

  FROM {{ ref('int_issue_tagged_socials') }} its
  INNER JOIN matched_tags mt
    ON its.retool_primary_key = mt.retool_primary_key
)

-- Select only the top alphabetically ranked row per post
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
  -- AND resolved_and_ranked.engagement_sub_type IS NOT NULL TODO: We can add this back in IF we ever get to a point where we feel like
  -- our pre-labeling captures all engagements
-- TODO: Add value testing for sector and category in schema
-- Add uniqueness test on...?

{{ config(schema='social_media_activity_archive') }}


WITH combined_data AS (
    SELECT * -- Explicitly name all columns (19)

    FROM {{ ref('int_tagged_records') }} -- Our top priority dataset

  UNION ALL

    SELECT * -- Explicitly name all columns (19)
    
    FROM {{ ref('int_benchmarking_analyst_subs') }} -- Our analyst submissions data, the highest true positive rate of any benchmarking input

  UNION ALL

    SELECT * -- Explicitly name all columns (19)

    FROM {{ref('int_non_socials_engagements') }} -- Our Google engagement scrape, typically returns more engagements than our socials processing

  UNION ALL

    SELECT * -- Explicitly name all columns (19)

    FROM {{ ref('int_issue_tagged_socials') }} -- Our social media engagement data, typically has a low rate of engagements per mil

),


-- Read in newsroom reference
corporate_newsrooms AS (

  SELECT TRIM(newsroom_url) AS newsroom_url

  FROM {{ ref('stg_corporate_reference')}}
),

-- Correct sectors & issue categories
category_sector_mapped AS (
  SELECT
    COALESCE(NULLIF(TRIM(cd.assignments), ''), 'Unassigned') AS assignments,
    corporation,
    date_posted,
    deleted_at,
    edit_notes,
    edit_status,
    `Engagement_Sub-Type`,
    Engagement_Type,
    event_group_id,
    is_deleted,
    post_text,
    product,
    retool_primary_key,
    row_status,
    summary,
    url,
    CASE
      WHEN cd.platform = 'Other' AND EXISTS (
        SELECT 1
        FROM corporate_newsrooms cn 
          WHERE STRPOS(LOWER(cd.url), LOWER(cn.newsroom_url)) > 0 )
            THEN 'Newsroom'
      ELSE cd.platform 
    END AS platform,
    INITCAP(REPLACE(TRIM(COALESCE(sm.new_sector, sector)), "’", "'")) AS corrected_sector,
    INITCAP(REPLACE(TRIM(COALESCE(cm.new_category, category)), "’", "'")) AS corrected_category

FROM combined_data cd

LEFT JOIN {{ ref('sector_map') }} sm 
    ON TRIM(LOWER(cd.sector)) = TRIM(LOWER(sm.old_sector))

LEFT JOIN {{ ref('category_map') }} cm 
    ON TRIM(LOWER(cd.category)) = TRIM(LOWER(cm.old_category))
)


SELECT *
    FROM (
  SELECT 
    assignments,
    corrected_category AS category,
    corporation,
    date_posted,
    deleted_at,
    edit_notes,
    edit_status,
    `Engagement_Sub-Type`,
    Engagement_Type,
    event_group_id,
    is_deleted,
    platform,
    post_text,
    product,
    retool_primary_key,
    row_status,
    corrected_sector AS sector,
    summary,
    url

  FROM category_sector_mapped csm

  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY retool_primary_key
    ORDER BY 
      CASE WHEN row_status = 'Labeled' THEN 1 ELSE 2 END ASC,
      CASE 
        WHEN platform = 'Newsroom'  THEN 1
        WHEN platform = 'LinkedIn'  THEN 2
        WHEN platform = 'Instagram' THEN 3
        WHEN platform = 'Twitter'   THEN 4
        WHEN platform = 'Other'     THEN 5
        ELSE 6 
      END ASC,
      date_posted DESC
    ) = 1
)

  WHERE COALESCE(is_deleted, false) = false 
    AND COALESCE(Engagement_Type, '') != 'Not an Engagement'
    AND corporation != 'None'
    
    ORDER BY
      row_status DESC,
      corporation,
      post_text,
      category,
      CASE
        WHEN edit_status = 'Awaiting Edits' THEN 1
        WHEN edit_status = 'Awaiting Revision' THEN 2
        WHEN edit_status = 'Not Reviewed' THEN 3
        ELSE 4
      END ASC,
      CASE 
        WHEN platform = 'Newsroom'  THEN 1
        WHEN platform = 'LinkedIn'  THEN 2
        WHEN platform = 'Instagram' THEN 3
        WHEN platform = 'Twitter'   THEN 4
        WHEN platform = 'Other'     THEN 5
        ELSE 6 
      END ASC,
      date_posted DESC
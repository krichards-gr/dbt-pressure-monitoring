--From the submissions table, grab only the rows that are not yet finalized in the CED AND which need to be split
WITH test_rows AS (
  SELECT submitted_on, corporation, sector, engagement_date, category, engagement_type, engagement_subtype, summary, url
FROM {{ ref('stg_benchmarking_analyst_subs') }}
WHERE completed = false -- I don't believe that this field is actually being utilized by submitters. How are we currently controlling for already-processed records?
AND (
      REGEXP_CONTAINS(corporation, r'[,;]')
      OR REGEXP_CONTAINS(category, r'[,;]')
    )
  ORDER BY submitted_on DESC
),

--Grab the rest of the rows from the submissions table (i.e., the ones that are not yet finalized in the CED but which DO NOT NEED TO BE SPLIT
other_rows AS (
  SELECT submitted_on, corporation, sector, engagement_date, category, engagement_type, engagement_subtype, summary, url
  FROM {{ ref('stg_benchmarking_analyst_subs') }}
  WHERE url NOT IN (SELECT url FROM test_rows)
  AND completed = false
  ORDER BY engagement_date DESC
),

--Operate on the rows that need to be split, first splitting by the corporation column...
corp_split AS (
SELECT * EXCEPT(corporation)
FROM test_rows,
UNNEST(SPLIT(REPLACE(corporation, ";", ","), ',')) as corporation
),

--...then splitting by the societal issue column
issue_split AS (
  SELECT * EXCEPT(category)
FROM corp_split,
UNNEST(SPLIT(REPLACE(category, ";", ","), ',')) as category
),

-- Get data from the tagged_records table
ExistingData AS (
  SELECT 
    B.retool_primary_key, B.corporation, B.sector, B.date_posted, B.post_text, B.url, 
    B.platform, B.category, B.Engagement_Type, B.`Engagement_Sub-Type`, B.summary, 
    B.event_group_id, C.assignments, 'Labeled' as row_status, B.edit_status, 
    B.is_deleted, B.deleted_at, B.edit_notes, C.product
  FROM 
    {{ source('social_media_activity_archive', 'tagged_records')}} AS B
  LEFT JOIN
    {{ ref('stg_corporate_reference') }} AS C 
  ON TRIM(LOWER(C.corporation)) = TRIM(LOWER(B.corporation))
),

-- Get data from the issue_tagged table
NewIncomingData AS (
  SELECT 
    REPLACE(TRIM(LOWER(COALESCE(A.corporation, ''))), ' ', '_') || '::' || 
    TRIM(LOWER(COALESCE(A.url, ''))) || '::' || 
    REPLACE(TRIM(LOWER(COALESCE(A.category, ''))), ' ', '_') 
    AS retool_primary_key,
    A.corporation, A.sector, A.date_posted, A.post_text, A.url, A.platform, A.category,
    NULLIF(A.engagement_type, '') as Engagement_Type,
    NULLIF(A.engagement_sub_type, '') as `Engagement_Sub-Type`,
    CAST(NULL as STRING) as summary, CAST(NULL as STRING) as event_group_id,
    C.assignments, 'Unlabeled' as row_status, 'Not Reviewed' as edit_status,
    CAST(NULL AS BOOLEAN) as is_deleted, CAST(NULL AS TIMESTAMP) as deleted_at,
    CAST(NULL as STRING) as edit_notes, C.product
  FROM 
    `sri-benchmarking-databases.social_media_activity_archive.benchmarking_issue_tagged` AS A -- TODO: build issue tagged int table
  LEFT JOIN
    {{ ref('stg_corporate_reference') }} AS C 
  ON TRIM(LOWER(C.corporation)) = TRIM(LOWER(A.corporation))
  WHERE (
      REPLACE(TRIM(LOWER(COALESCE(A.corporation, ''))), ' ', '_') || '::' || 
      TRIM(LOWER(COALESCE(A.url, ''))) || '::' || 
      REPLACE(TRIM(LOWER(COALESCE(A.category, ''))), ' ', '_')
    ) NOT IN (SELECT retool_primary_key FROM ExistingData)
  AND DATE(A.date_posted) >= '2025-12-03' -- TODO: What's going on with this here?
),

combinedData AS (
    SELECT * FROM ExistingData
    UNION ALL
    SELECT * FROM NewIncomingData
),

combinedAnalystInputs AS (
SELECT * FROM (
  SELECT TRIM(REPLACE(Corporation, 'and', '')) as corporation,
      Industry as sector,
      CAST(Date_of_engagement AS TIMESTAMP) as date_posted,
      CAST(NULL AS STRING) post_text,
      Link as url,
      CAST(NULL AS STRING) as platform,
      category,
      Engagement_type as Engagement_Type,
      Engagement_sub_category as `Engagement_Sub-Type`,
      Details as summary,
      CAST(NULL AS STRING) as event_group_id,
      'Harrison Firestone' as assignments,
      'Unlabeled' as row_status
  FROM issue_split A
UNION ALL
SELECT Corporation as corporation,
      Industry as sector,
      CAST(Date_of_engagement AS TIMESTAMP) as date_posted,
      CAST(NULL AS STRING) post_text,
      Link as url,
      CAST(NULL AS STRING) as platform,
      Societal_issues as category,
      Engagement_type as Engagement_Type,
      Engagement_sub_category as `Engagement_Sub-Type`,
      Details as summary,
      CAST(NULL AS STRING) as event_group_id,
      'Harrison Firestone' as assignments,
      'Unlabeled' as row_status
  FROM other_rows
  ORDER BY date_posted DESC
  )
  WHERE DATE(date_posted) >= '2025-12-03'
),

inputs_w_sector AS (
  SELECT
      A.corporation, B.sector, CAST(A.date_posted AS TIMESTAMP) as date_posted,
      A.post_text, A.url,
      CASE WHEN A.url LIKE '%instagram%' THEN 'Instagram'
        WHEN A.url LIKE '%linkedin%' THEN 'LinkedIn'
        WHEN A.url LIKE '%/x.com%' THEN 'Twitter'
        ELSE 'Other'
      END as platform,
      A.category, A.Engagement_Type, A.`Engagement_Sub-Type`, A.summary, A.event_group_id,
      COALESCE(A.assignments, B.assignments) as assignments,
      'Analyst Inputs' as row_status, 'Not Reviewed' as edit_status, B.product
      FROM combinedAnalystInputs A
      LEFT JOIN {{ ref('stg_corporate_reference') }} AS B
      ON TRIM(LOWER(B.corporation)) = TRIM(LOWER(A.corporation))
),

rawCedData as (
  SELECT * EXCEPT(confidence_assessment)
FROM (
  SELECT
    corporation, industry AS sector,
    CAST(COALESCE(SAFE.PARSE_DATE('%Y-%m-%d', date), SAFE.PARSE_DATE('%m/%d/%Y', date)) AS TIMESTAMP) AS date_posted,
    quick_review AS post_text, link AS url,
    CASE WHEN link LIKE '%instagram%' THEN 'Instagram'
      WHEN link LIKE '%linkedin%' THEN 'LinkedIn'
      WHEN link LIKE '%/x.com%' THEN 'Twitter'
      ELSE 'Other'
    END AS platform,
    issue_area AS category, engagement_type AS Engagement_Type,
    engagement_subcategory AS `Engagement_Sub-Type`, summary,
    CAST(NULL AS STRING) AS event_group_id, CAST(NULL AS STRING) AS assignments,
    'Unlabeled' AS row_status, confidence_assessment,
    REPLACE(TRIM(LOWER(COALESCE(corporation, ''))), ' ', '_') || '::' || TRIM(LOWER(COALESCE(link, ''))) || '::' || REPLACE(TRIM(LOWER(COALESCE(issue_area, ''))), ' ', '_') AS retool_primary_key,
  FROM {{ ref('stg_non_socials_engagements') }}
  QUALIFY ROW_NUMBER() OVER (PARTITION BY link ORDER BY CAST(confidence_assessment AS INT64) DESC) = 1 )
WHERE CAST(confidence_assessment AS INT64) >= 80
),
  
cedLabeled as (
  SELECT 
    A.retool_primary_key, A.corporation, COALESCE(B.sector, A.sector) as sector,
    A.date_posted, A.post_text, A.url, A.platform, A.category, A.Engagement_Type,
    A.`Engagement_Sub-Type`, A.summary, A.event_group_id,
    COALESCE(NULLIF(TRIM(B.assignments), ''), 'Unassigned') AS assignments,
    A.row_status, 'Not Reviewed' as edit_status,
    CAST(NULL AS BOOLEAN) as is_deleted, CAST(NULL AS TIMESTAMP) as deleted_at,
    CAST(NULL as STRING) as edit_notes, B.product
  FROM rawCedData AS A
  LEFT JOIN {{ ref('stg_corporate_reference') }} AS B
  ON TRIM(LOWER(B.corporation)) = TRIM(LOWER(A.corporation))
  WHERE DATE(A.date_posted) >= '2025-12-01' OR A.date_posted IS NULL
),
  
unioned_results AS (
  SELECT * FROM combinedData
  UNION ALL
  SELECT
    REPLACE(TRIM(LOWER(COALESCE(A.corporation, ''))), ' ', '_') || '::' || 
    TRIM(LOWER(COALESCE(A.url, ''))) || '::' || 
    REPLACE(TRIM(LOWER(COALESCE(A.category, ''))), ' ', '_') 
    AS retool_primary_key,
    A.corporation, A.sector, A.date_posted, A.post_text, A.url, A.platform, A.category,
    A.Engagement_Type, A.`Engagement_Sub-Type`, A.summary, A.event_group_id, A.assignments,
    A.row_status, A.edit_status, 
    CAST(NULL AS BOOLEAN) as is_deleted, CAST(NULL AS TIMESTAMP) as deleted_at,
    CAST(NULL as STRING) as edit_notes, A.product
  FROM inputs_w_sector A
  UNION ALL
  SELECT * FROM cedLabeled
),

sector_map AS (
  SELECT * FROM UNNEST([
    STRUCT('Communications Services' AS old_label, 'Tech' AS new_label),
    STRUCT('Consumer Discretionary', 'Consumer Goods'),
    STRUCT('Consumer Staples', 'Consumer Goods'),
    STRUCT('Financials', 'Financial'),
    STRUCT('Healthcare', 'Health'),
    STRUCT('Information Technology', 'Tech'),
    STRUCT('Technology', 'Tech'),
    STRUCT('Other', 'Non-Corporate Organization'),
    STRUCT('Nonprofit', 'Non-Corporate Organization')
  ])
),

category_map AS (
  SELECT * FROM UNNEST([
    STRUCT('AI/Tech' AS old_label, 'AI & Technology' AS new_label),
    STRUCT('Artificial Intelligence', 'AI & Technology'),
    STRUCT('Climate Change', 'Climate Change & Sustainability'),
    STRUCT('Disaster Relief', 'Climate Change & Sustainability'),
    STRUCT('Sustainability', 'Climate Change & Sustainability'),
    STRUCT('2024 Election', 'Elections & Administration'),
    STRUCT('Election Integrity & Voting Rights', 'Elections & Administration'),
    STRUCT('Financials', 'Financial Sector Risks'),
    STRUCT('Health Equity', 'Health Access'),
    STRUCT('Healthcare Access', 'Health Access'),
    STRUCT('International Reputational Risk', 'International Reputational Risks'),
    STRUCT('Nutrition & Food access', 'Nutrition & Food Access'),
    STRUCT('Political Expression', 'Religious & Political Diversity'),
    STRUCT('Religious Diversity', 'Religious & Political Diversity'),
    STRUCT("Workers’ Rights", "Workers' Rights"),
    STRUCT("Veteran's Rights", "Veterans' Rights") 
  ])
),

corporate_newsrooms AS (
  SELECT DISTINCT newsroom_url 
  FROM {{ ref('stg_corporate_reference') }}
  WHERE newsroom_url IS NOT NULL AND newsroom_url != ''
)

SELECT *
  FROM (
SELECT 
  t.* EXCEPT(sector, category, assignments, platform),
  CASE 
    WHEN t.platform = 'Other' AND EXISTS (
    SELECT 1 FROM corporate_newsrooms cn 
    WHERE STRPOS(LOWER(t.url), LOWER(cn.newsroom_url)) > 0    ) THEN 'Newsroom'
    ELSE t.platform 
  END AS platform,
  TRIM(COALESCE(sm.new_label, TRIM(t.sector))) AS sector,
  TRIM(COALESCE(cm.new_label, TRIM(t.category))) AS category,
  COALESCE(NULLIF(TRIM(t.assignments), ''), 'Unassigned') AS assignments
FROM unioned_results t
LEFT JOIN sector_map sm ON TRIM(LOWER(t.sector)) = TRIM(LOWER(sm.old_label))
LEFT JOIN category_map cm ON TRIM(LOWER(t.category)) = TRIM(LOWER(cm.old_label))
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
-- Just pull from on_demand_socials and join/filter on found key terms
-- Build in issue pre-labeling at some point
-- And of course optimize iteratively

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['corporation', 'category', 'url'],
    schema='social_media_activity_archive'
) }}


-- TODO: Add incremental logic here


-- ==============================================================================
-- 2. FILTER: IDENTIFY ONLY NEW POSTS
-- ==============================================================================

WITH new_posts AS (

SELECT
    ods.corporation,
    ods.sector,
    ods.date_posted,
    ods.post_text,
    ods.url,
    ods.platform, -- TODO: Do we need this here?
    ods.product -- TODO: Do we need this here?

FROM {{ ref('int_on_demand_socials') }} ods

-- On first run / full refresh, check against the legacy source table
-- On incremental runs, check against the dbt-managed table instead
{% if is_incremental() %}

LEFT JOIN {{ this }} existing

    ON ods.url = existing.url AND ods.corporation = existing.corporation

    WHERE existing.url IS NULL -- Keep only rows that are NOT in the existing table

{% else %}
    
    WHERE ods.type = "Organization"

{% endif %}

    
),

-- ==============================================================================
-- 2. TRANSLATION LOGIC (Only runs on new_posts)
-- TODO: How can we bring down cost on this step?
-- ==============================================================================

Target_For_Translation AS (
    SELECT 
        corporation, sector, date_posted, url, platform, post_text, product,
        CONCAT(
            'Translate to English. If English, return as-is. Text: [post_text]\n\n',
            'Text: ', post_text
        ) AS prompt
    FROM new_posts 
    WHERE date_posted > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
        AND post_text IS NOT NULL AND TRIM(post_text) != ''
        AND REGEXP_CONTAINS(post_text, r'[^\x00-\x7F]')  -- only non-ASCII (likely non-English)
),

-- Posts that are new but don't meet translation criteria (old date or empty text)
Unprocessed_New_Data AS (
    SELECT * FROM new_posts 
    WHERE NOT (
        date_posted > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
        AND post_text IS NOT NULL AND TRIM(post_text) != ''
        AND REGEXP_CONTAINS(post_text, r'[^\x00-\x7F]')
    )
),

Translated_Batch AS (
    SELECT
        corporation,
        sector,
        date_posted,
        COALESCE(
            JSON_VALUE(ml_generate_text_result, '$.candidates[0].content.parts[0].text'), 
            post_text
        ) AS post_text,
        url,
        platform,
        product
    FROM ML.GENERATE_TEXT(
        MODEL `sri-benchmarking-databases.social_media_activity_archive.llm_model`, 
        (SELECT * FROM Target_For_Translation),
        STRUCT(
            0 AS temperature, 
            1024 AS max_output_tokens
        )
    )
),

NewPosts_Ready AS (
    SELECT * FROM Unprocessed_New_Data
    UNION ALL
    SELECT * FROM Translated_Batch
),


-- ==============================================================================
-- 3. FINAL MATCHING & INSERT
-- ==============================================================================

issue_labeled AS (
SELECT 
    np.corporation,
    np.sector,
    np.date_posted,
    np.post_text, 
    np.url,
    np.platform,
    COALESCE(it.category, 'no_issue_match') as category,
    STRING_AGG(DISTINCT it.key_terms, ', ') AS matched_terms, -- List of terms that matched from our reference set
    CAST(NULL as INT64) as is_engagement,
    CAST(NULL as STRING) as engagement_type,
    CAST(NULL as STRING) as engagement_sub_type
FROM NewPosts_Ready np

LEFT JOIN {{ ref('stg_issue_term_reference') }} it -- Check whether the post text contains any of our list of issue terms
    ON REGEXP_CONTAINS(
        LOWER(np.post_text), 
        CONCAT(r'\b', LOWER(TRIM(it.key_terms)), r'\b')
    )
GROUP BY -- Create one row for each category found for each input record
    np.corporation,
    np.sector,
    np.date_posted,
    np.post_text,
    np.url,
    np.platform,
    it.category
)

-- TODO: Add engagement type pre-labeling (similar to issue labeling above)

SELECT cr.assignments,
       il.category,
       il.corporation,
       il.date_posted,
       CAST(NULL AS TIMESTAMP) as deleted_at,
       CAST(NULL as STRING) as edit_notes,
       'Not Reviewed' as edit_status,
       CAST(NULL as STRING) as engagement_type,
       CAST(NULL as STRING) as engagement_sub_type,
       CAST(NULL as STRING) as event_group_id,
       CAST(NULL AS BOOLEAN) as is_deleted,
       il.platform,
       il.post_text,
       cr.product,
       REPLACE(TRIM(LOWER(COALESCE(il.corporation, ''))), ' ', '_') || '::' || TRIM(LOWER(COALESCE(url, ''))) || '::' || REPLACE(TRIM(LOWER(COALESCE(category, ''))), ' ', '_') 
            AS retool_primary_key,
       'Unlabeled' AS row_status,
       cr.sector,
       CAST(NULL as STRING) as summary,
       il.url

FROM issue_labeled il

LEFT JOIN {{ ref('stg_corporate_reference') }} cr
    ON il.corporation = cr.corporation

-- Filter out records that already exist in our final CED table (tagged_records)
WHERE (REPLACE(TRIM(LOWER(COALESCE(il.corporation, ''))), ' ', '_') || '::' || TRIM(LOWER(COALESCE(il.url, ''))) || '::' || REPLACE(TRIM(LOWER(COALESCE(il.category, ''))), ' ', '_')
    ) NOT IN ( --- TODO: Swap to NOT EXISTS for safety
        SELECT retool_primary_key
        FROM {{ ref('int_tagged_records')}}
      )
--   AND DATE(il.date_posted) >= '2025-12-03'
  AND category != "no_issue_match"
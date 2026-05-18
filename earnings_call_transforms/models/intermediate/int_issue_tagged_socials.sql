-- Just pull from on_demand_socials and join/filter on found key terms
-- Build in issue pre-labeling at some point
-- And of course optimize iteratively

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['category', 'url'],
    schema='social_media_activity_archive'
) }}


-- TODO: Add incremental logic here


-- ==============================================================================
-- 2. FILTER: IDENTIFY ONLY NEW POSTS
-- This filters our records already tagged by checking whether url is present. This DOES NOT effectivly filter out records that have already been...
-- ..processed, but that were affirmatively excluded because they didn't match any issue category terms
-- TODO: How can we build this in, knowing that we need to translate?
-- ==============================================================================

INNER JOIN {{ ref(stg_issue_term_reference) }}

WITH new_posts AS (

SELECT
    type,
    executive_name,
    corporation,
    sector,
    date_posted,
    post_text,
    url,
    platform,
    product

FROM {{ ref(int_on_demand_socials) }} ods

LEFT JOIN {{ source('social_media_activity_archive', 'benchmarking_issue_tagged')}} existing
    ON ap.url = existing.url

WHERE existing.url IS NULL -- Keep only rows that are NOT in the existing table
),

-- ==============================================================================
-- 2. TRANSLATION LOGIC (Only runs on new_posts)
-- TODO: How can we bring down cost on this step?
-- ==============================================================================

Target_For_Translation AS (
    SELECT 
        corporation, sector, date_posted, url, platform, post_text,
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
    WHERE date_posted <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
        OR date_posted IS NULL
        OR TRIM(post_text) = ''
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
        platform
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
)

-- grab on demand rows
-- drop any that don't match issue category key terms (inner join)
-- drop any records already in issue_tagged


-- INSERT INTO `sri-benchmarking-databases.social_media_activity_archive.benchmarking_issue_tagged` 
-- (corporation, sector, date_posted, post_text, url, platform, category, matched_terms, is_engagement, engagement_type, engagement_sub_type)







-- ==============================================================================
-- 4. FINAL MATCHING & INSERT
-- ==============================================================================

SELECT 
    np.corporation,
    np.sector,
    np.date_posted,
    np.post_text, 
    np.url,
    np.platform,
    it.category,
    STRING_AGG(DISTINCT it.key_terms, ', ') AS matched_terms,
    CAST(NULL as INT64) as is_engagement,
    CAST(NULL as STRING) as engagement_type,
    CAST(NULL as STRING) as engagement_sub_type
FROM NewPosts_Ready np
INNER JOIN `sri-benchmarking-databases.social_media_activity_archive.benchmarking_issue_terms` it
    ON REGEXP_CONTAINS(
        LOWER(np.post_text), 
        CONCAT(r'\b', LOWER(TRIM(it.key_terms)), r'\b')
    )
GROUP BY
    np.corporation,
    np.sector,
    np.date_posted,
    np.post_text,
    np.url,
    np.platform,
    it.category
    
ORDER BY date_posted DESC;
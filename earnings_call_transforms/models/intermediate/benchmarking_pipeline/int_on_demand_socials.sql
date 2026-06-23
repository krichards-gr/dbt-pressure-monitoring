{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['url'],
    schema='social_media_activity_archive'
) }}

WITH 
-- First, define the LinkedIn data CTEs
LinkedInCombined AS (
    -- This CTE gathers all possible matches from both sources.
    -- Priority 1: JSON_EXTRACT match (preferred)
    -- Priority 2: use_url match (fallback)

    -- Match on discovery_input
    SELECT 
        corporation, 
        sector, 
        date_posted, 
        post_text, 
        url,
        1 AS source_priority
    FROM {{ ref('stg_corporate_reference') }} bcr
    INNER JOIN {{ ref('stg_linkedin_posts') }} AS lp 
        ON bcr.linkedin_url = JSON_EXTRACT_SCALAR(lp.discovery_input, '$.url')
    WHERE lp.discovery_input IS NOT NULL 
        AND lp.discovery_input != '' 
        AND SAFE.PARSE_JSON(lp.discovery_input) IS NOT NULL
        {% if is_incremental() %}
        AND lp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
        
    UNION ALL
    
    -- Match on use_url (after stripping query parameters)
    SELECT 
        corporation, 
        sector, 
        date_posted, 
        post_text, 
        url,
        2 AS source_priority
    FROM {{ ref('stg_corporate_reference') }} bcr
    INNER JOIN {{ ref('stg_linkedin_posts') }} AS lp 
        ON RTRIM(bcr.linkedin_url, '/') = IF(
            STRPOS(lp.use_url, '?') = 0,
            lp.use_url,
            SUBSTR(lp.use_url, 1, STRPOS(lp.use_url, '?') - 1)
        )
    -- FIX: Removed discovery_input IS NULL exclusion to allow fallback execution
    WHERE lp.use_url IS NOT NULL 
        AND lp.use_url != ''
        {% if is_incremental() %}
        AND lp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
),

LinkedInRanked AS (
    SELECT
        corporation,
        sector,
        date_posted,
        post_text,
        url,
        ROW_NUMBER() OVER(
            PARTITION BY url 
            ORDER BY source_priority ASC
        ) AS rn
    FROM LinkedInCombined
),

-- Second, define the Instagram data CTEs
InstagramCombined AS (
    -- Match on discovery_input
    SELECT 
        corporation, 
        sector, 
        date_posted, 
        ip.description,
        url,
        1 AS source_priority
    FROM {{ ref('stg_corporate_reference') }} bcr
    INNER JOIN {{ ref('stg_instagram_posts') }} ip 
        ON bcr.instagram_url = JSON_EXTRACT_SCALAR(ip.discovery_input, '$.url')
    WHERE ip.discovery_input IS NOT NULL 
        AND ip.discovery_input != '' 
        AND SAFE.PARSE_JSON(ip.discovery_input) IS NOT NULL
        {% if is_incremental() %}
        AND ip.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
 
    UNION ALL
    
    -- Match on profile_url   
    SELECT 
        corporation, 
        sector, 
        date_posted, 
        ip.description,
        url,
        2 AS source_priority
    FROM {{ ref('stg_corporate_reference') }} bcr
    INNER JOIN {{ ref('stg_instagram_posts') }} ip 
        ON RTRIM(bcr.instagram_url, '/') = ip.profile_url
    -- FIX: Removed discovery_input IS NULL exclusion to allow fallback execution
    WHERE ip.profile_url IS NOT NULL 
        AND ip.profile_url != ''
        {% if is_incremental() %}
        AND ip.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
),

InstagramRanked AS (
    SELECT
        corporation,
        sector,
        date_posted,
        description,
        url,
        ROW_NUMBER() OVER(
            PARTITION BY url 
            ORDER BY source_priority ASC
        ) AS rn
    FROM InstagramCombined
),

-- Define the Twitter data CTEs
TwitterCombined AS (
    -- Match on discovery_input
    SELECT 
        corporation, 
        sector, 
        date_posted, 
        tp.description, 
        url,
        1 AS source_priority
    FROM {{ ref('stg_corporate_reference') }} bcr
    INNER JOIN {{ ref('stg_x_posts') }} AS tp 
        ON bcr.x_url = JSON_EXTRACT_SCALAR(tp.discovery_input, '$.url')
    WHERE tp.discovery_input IS NOT NULL 
        AND tp.discovery_input != '' 
        AND SAFE.PARSE_JSON(tp.discovery_input) IS NOT NULL
        {% if is_incremental() %}
        AND tp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
        
    UNION ALL
    
    -- Match on url (strip /status suffix)
    SELECT 
        corporation, 
        sector, 
        date_posted, 
        tp.description, 
        url,
        2 AS source_priority
    FROM {{ ref('stg_corporate_reference') }} bcr
    INNER JOIN {{ ref('stg_x_posts') }} AS tp 
        ON bcr.x_url = IF(
            STRPOS(tp.url, '/status') = 0,
            tp.url,
            SUBSTR(tp.url, 1, STRPOS(tp.url, '/status') - 1)
        )
    -- FIX: Removed discovery_input IS NULL exclusion to allow fallback execution
    WHERE tp.url IS NOT NULL 
        AND tp.url != ''
        {% if is_incremental() %}
        AND tp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
),

TwitterRanked AS (
    SELECT
        corporation,
        sector,
        date_posted,
        description,
        url,
        ROW_NUMBER() OVER(
            PARTITION BY url 
            ORDER BY source_priority ASC
        ) AS rn
    FROM TwitterCombined
),

-- Define the CEO Twitter data CTEs
CEOTwitterCombined AS (
    -- Match on discovery_input
    SELECT 
        corporation,
        executive_name,
        executive_type,
        sector,
        date_posted,
        ctp.description,
        url,
        1 AS source_priority
    FROM {{ ref('stg_ceo_reference') }} cbr
    INNER JOIN {{ ref('stg_ceo_x_posts') }} AS ctp 
        ON cbr.x_url = JSON_EXTRACT_SCALAR(ctp.discovery_input, '$.url')
    WHERE ctp.discovery_input IS NOT NULL 
        AND ctp.discovery_input != '' 
        AND SAFE.PARSE_JSON(ctp.discovery_input) IS NOT NULL
        {% if is_incremental() %}
        AND ctp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
        
    UNION ALL
    
    -- Match on url (strip /status suffix)
    SELECT 
        corporation,
        executive_name,
        executive_type,
        sector,
        date_posted,
        ctp.description,
        url,
        2 AS source_priority
    FROM {{ ref('stg_ceo_reference') }} cbr
    INNER JOIN {{ ref('stg_ceo_x_posts') }} AS ctp 
        ON cbr.x_url = IF(
            STRPOS(ctp.url, '/status') = 0,
            ctp.url,
            SUBSTR(ctp.url, 1, STRPOS(ctp.url, '/status') - 1)
        )
    -- FIX: Removed discovery_input IS NULL exclusion to allow fallback execution
    WHERE ctp.url IS NOT NULL 
        AND ctp.url != ''
        {% if is_incremental() %}
        AND ctp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
),

CEOTwitterRanked AS (
    SELECT
        corporation,
        executive_name,
        executive_type,
        sector,
        date_posted,
        description,
        url,
        ROW_NUMBER() OVER(
            PARTITION BY url 
            ORDER BY source_priority ASC
        ) AS rn
    FROM CEOTwitterCombined
),

-- Define the CEO LinkedIn data CTEs
CEOLinkedInCombined AS (
    -- Match on discovery_input
    SELECT 
        corporation,
        executive_name,
        executive_type,
        sector,
        date_posted,
        post_text,
        url,
        1 AS source_priority
    FROM {{ ref('stg_ceo_reference') }} cbr
    INNER JOIN {{ ref('stg_ceo_linkedin_posts') }} AS clp 
        ON cbr.linkedin_url = JSON_EXTRACT_SCALAR(clp.discovery_input, '$.url')
    WHERE clp.discovery_input IS NOT NULL 
        AND clp.discovery_input != '' 
        AND SAFE.PARSE_JSON(clp.discovery_input) IS NOT NULL
        {% if is_incremental() %}
        AND clp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
        
    UNION ALL
    
    -- Match on use_url (after stripping query parameters)
    SELECT 
        corporation,
        executive_name,
        executive_type,
        sector,
        date_posted,
        post_text,
        url,
        2 AS source_priority
    FROM {{ ref('stg_ceo_reference') }} cbr
    INNER JOIN {{ ref('stg_ceo_linkedin_posts') }} AS clp 
        ON RTRIM(cbr.linkedin_url, '/') = IF(
            STRPOS(clp.use_url, '?') = 0,
            clp.use_url,
            SUBSTR(clp.use_url, 1, STRPOS(clp.use_url, '?') - 1)
        )
    -- FIX: Removed discovery_input IS NULL exclusion to allow fallback execution
    WHERE clp.use_url IS NOT NULL 
        AND clp.use_url != ''
        {% if is_incremental() %}
        AND clp.url NOT IN (SELECT url FROM {{ this }} WHERE url IS NOT NULL)
        {% endif %}
),

CEOLinkedInRanked AS (
    SELECT
        corporation,
        executive_name,
        executive_type,
        sector,
        SAFE_CAST(date_posted AS TIMESTAMP) as date_posted,
        post_text,
        url,
        ROW_NUMBER() OVER(
            PARTITION BY url 
            ORDER BY source_priority ASC
        ) AS rn
    FROM CEOLinkedInCombined
),

-- Combine all posts into a single unified table
AllPosts AS (
    SELECT
        executive_type AS type,
        corporation,
        executive_name,
        sector,
        SAFE_CAST(date_posted AS TIMESTAMP) as date_posted,
        post_text,
        url,
        'LinkedIn' AS platform
    FROM CEOLinkedInRanked
    WHERE rn = 1

    UNION ALL
    
    SELECT
        executive_type AS type,
        corporation,
        executive_name,
        sector,
        SAFE_CAST(date_posted AS TIMESTAMP) as date_posted,
        description AS post_text,
        url,
        'Twitter' AS platform
    FROM CEOTwitterRanked
    WHERE rn = 1

    UNION ALL

    SELECT
        'Organization' AS type,
        corporation,
        NULL AS executive_name,
        sector,
        SAFE_CAST(date_posted AS TIMESTAMP) as date_posted,
        post_text,
        url,
        'LinkedIn' AS platform
    FROM LinkedInRanked
    WHERE rn = 1

    UNION ALL

    SELECT
        'Organization' AS type,
        corporation,
        NULL AS executive_name,
        sector,
        SAFE_CAST(date_posted AS TIMESTAMP) as date_posted,
        description AS post_text,
        url,
        'Instagram' AS platform
    FROM InstagramRanked
    WHERE rn = 1
    
    UNION ALL
    
    SELECT
        'Organization' AS type,
        corporation,
        NULL AS executive_name,
        sector,
        SAFE_CAST(date_posted AS TIMESTAMP) as date_posted,
        description AS post_text,
        url,
        'Twitter' AS platform
    FROM TwitterRanked
    WHERE rn = 1
)

-- Final selection: join back to reference for product column
SELECT 
    ap.type,
    ap.executive_name,
    ap.corporation,
    ap.sector,
    ap.date_posted,
    ap.post_text,
    ap.url,
    ap.platform,
    bcr.product
FROM AllPosts ap
LEFT JOIN {{ ref('stg_corporate_reference') }} bcr
    ON ap.corporation = bcr.corporation
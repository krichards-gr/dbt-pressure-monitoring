{{ config(schema='social_media_activity_archive') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT 
    TRIM(assignments) AS assignments,
    TRIM(corporation) AS corporation,
    TRIM(sector) AS sector,
    TRIM(profile_url) AS linkedin_url,
    TRIM(instagram_url) AS instagram_url,
    TRIM(newsroom_url) AS newsroom_url,
    TRIM(x_url) AS x_url,
    cik_SEC_lookup AS cik, -- Enforce integer here
    TRIM(peers_of) AS peer_of,
    rank, -- Enforce integer here
    F100 AS f100,
    F500 AS f500,
    TRIM(parent) AS parent,
    TRIM(UPPER(ticker)) AS symbol, -- Enforce uppercase here
    TRIM(Product) AS product

FROM {{ source('social_media_activity_archive', 'external_benchmarking_corporate_reference') }}

QUALIFY ROW_NUMBER() OVER (PARTITION BY corporation ORDER BY rank DESC) = 1
SELECT 
    TRIM(corporation) as corporation,
    TRIM(sector) as sector,
    TRIM(linkedin_url) as linkedin_url,
    TRIM(instagram_url) as instagram_url,
    TRIM(x_url) as x_url,
    cik, -- Enforce integer here
    TRIM(peer_of) as peer_of,
    rank, -- Enforce integer here
    F100 as f100,
    F500 as f500,
    TRIM(parent) as parent,
    TRIM(UPPER(ticker)) as symbol, -- Enforce uppercase here

FROM {{ source('social_media_activity_archive', 'benchmarking_corporate_reference') }}

QUALIFY ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY rank DESC) = 1
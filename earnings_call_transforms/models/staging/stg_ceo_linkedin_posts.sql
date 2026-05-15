{{ config(schema='social_media_activity_archive') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT *

FROM {{ source('social_media_activity_archive', 'ceo_linkedin_posts') }}

WHERE TRIM(post_text) != '' -- Ensure that no key columns are missing values
  AND date_posted IS NOT NULL
  AND TRIM(discovery_input) != ''
  AND TRIM(url) != ''

QUALIFY ROW_NUMBER() OVER (PARTITION BY url ORDER BY date_posted DESC) = 1 -- Select most recent post if duplicate found (on post url)
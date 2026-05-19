{{ config(schema='non_socials_engagement_data') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT NULLIF(TRIM(id), '') AS id,
NULLIF(TRIM(corporation), '') AS corporation,
NULLIF(TRIM(industry), '') AS sector,
CAST(COALESCE(SAFE.PARSE_DATE('%Y-%m-%d', date), SAFE.PARSE_DATE('%m/%d/%Y', date)) AS TIMESTAMP) AS date_posted,
NULLIF(TRIM(engagement_type), '') AS engagement_type,
NULLIF(TRIM(engagement_subcategory), '') AS engagement_subtype,
NULLIF(TRIM(issue_area), '') AS category,
publish_date,
NULLIF(TRIM(link), '') AS url,
confidence_assessment,
NULLIF(TRIM(quick_review), '') AS post_text,
NULLIF(TRIM(summary), '') AS summary


FROM {{ source('non_socials_engagement_data', 'engagement_data_outputs_raw') }}

WHERE TRIM(corporation) != '' -- Ensure that no key columns are missing values
  AND TRIM(issue_area) != ''
  AND TRIM(link) != ''

QUALIFY ROW_NUMBER() OVER (PARTITION BY corporation, issue_area, link ORDER BY confidence_assessment DESC) = 1 -- Select most confident record if duplicate found (on post url)
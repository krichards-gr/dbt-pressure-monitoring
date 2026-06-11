-- TODO: What other cleanup and enforcement do we need to do here?

{{ config(schema='social_media_activity_archive') }}

SELECT
  NULLIF(TRIM(LOWER(category)), '') AS category,
  NULLIF(TRIM(LOWER(key_terms)), '') AS key_terms,
  NULLIF(TRIM(LOWER(product)), '') AS product

  FROM {{ source('social_media_activity_archive', 'external_issue_term_reference') }}

  WHERE TRIM(category) != '' AND TRIM(key_terms) != ''

  QUALIFY ROW_NUMBER() OVER (PARTITION BY category, key_terms) = 1 -- Deduplication is intentionally deterministic
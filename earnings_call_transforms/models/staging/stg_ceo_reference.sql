{{ config(schema='social_media_activity_archive') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT
  NULLIF(TRIM(corporation), '') AS corporation,
  NULLIF(TRIM(executive_name), '') AS executive_name,
  NULLIF(TRIM(sector), '') AS sector,
  NULLIF(TRIM(linkedin_url), '') AS linkedin_url,
  NULLIF(TRIM(twitter_url), '') AS x_url,
  rank,
  NULLIF(TRIM(executive_type), '') AS executive_type

  FROM {{ source('social_media_activity_archive', 'external_ceo_benchmarking_reference') }}

  WHERE TRIM(corporation) != '' AND TRIM(executive_name) != '' -- Ensure that neither of the key columns are missing values

  QUALIFY ROW_NUMBER() OVER (PARTITION BY corporation, executive_name) = 1 -- Arbitrarily choose one if duplicates (company + CEO) are present
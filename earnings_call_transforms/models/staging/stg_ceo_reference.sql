-- TODO: What other cleanup and enforcement do we need to do here?

{{ config(materialized='view', schema='social_media_activity_archive') }}

SELECT
  NULLIF(TRIM(corporation), '') AS corporation,
  NULLIF(TRIM(chief_executive_officer), '') AS chief_executive_officer,
  NULLIF(TRIM(sector), '') AS sector,
  NULLIF(TRIM(linkedin_url), '') AS linkedin_url,
  NULLIF(TRIM(x_url), '') AS x_url

  FROM {{ source('social_media_activity_archive', 'external_ceo_benchmarking_reference') }}

  WHERE TRIM(corporation) != '' AND TRIM(chief_executive_officer) != ''

  QUALIFY ROW_NUMBER() OVER (PARTITION BY corporation, chief_executive_officer) = 1
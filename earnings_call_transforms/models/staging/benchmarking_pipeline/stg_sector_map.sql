{{ config(schema='social_media_activity_archive', materialized='view') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT
    old_sector,
    new_sector

FROM {{ source('social_media_activity_archive', 'external_sector_map')}}

  QUALIFY ROW_NUMBER() OVER (PARTITION BY old_sector) = 1 -- Arbitrarily choose one if duplicates are present
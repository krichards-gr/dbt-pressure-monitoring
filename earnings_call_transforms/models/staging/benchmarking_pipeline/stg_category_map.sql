{{ config(schema='social_media_activity_archive', materialized='view') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT
    old_category,
    new_category

FROM {{ source('social_media_activity_archive', 'external_category_map')}}

QUALIFY ROW_NUMBER() OVER (PARTITION BY old_category) = 1 -- Arbitrarily choose one if duplicates are present
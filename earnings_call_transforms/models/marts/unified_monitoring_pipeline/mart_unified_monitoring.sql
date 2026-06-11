{{ config(schema='social_media_activity_archive') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

-- TODO: What tests do we need on this table?

SELECT
  date,
  category,
  story_count,
  engagement_count

FROM {{ ref('int_unified_monitoring') }}
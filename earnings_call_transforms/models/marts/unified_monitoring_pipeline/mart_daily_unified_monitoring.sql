{{
    config(
        schema='social_media_activity_archive',
        materialized = 'table',
        partition_by = {
            "field": "date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by = ['category']
    )
}}
-- TODO: What tests do we need on this table?

SELECT
  date,
  category,
  story_count,
  engagement_count

FROM {{ ref('int_daily_unified_monitoring') }}
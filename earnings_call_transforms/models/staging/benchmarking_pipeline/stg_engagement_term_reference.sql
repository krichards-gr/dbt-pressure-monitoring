{{ config(schema='social_media_activity_archive') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT key_terms,
    engagement_sub_type,
    engagement_type

FROM {{ source('social_media_activity_archive', 'external_engagement_term_reference')}}
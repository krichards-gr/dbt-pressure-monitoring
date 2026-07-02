{{
    config(
        schema='social_media_activity_archive',
        materialized = 'table',
        partition_by = {
            "field": "date_posted",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by = ['category', 'sector']
    )
}}

SELECT 
    assignments,
    category,
    corporation,
    date_posted,
    deleted_at,
    edit_notes,
    edit_status,
    `Engagement_Sub-Type`,
    Engagement_Type,
    event_group_id,
    is_deleted,
    platform,
    post_text,
    product,
    retool_primary_key,
    row_status,
    sector,
    summary,
    url

FROM {{ ref('int_unvalidated_benchmarking' )}}
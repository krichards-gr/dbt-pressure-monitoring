{{ config(schema='social_media_activity_archive', materialized='view') }}

SELECT 
    retool_primary_key,
    corporation,
    sector,
    date_posted,
    post_text,
    url, 
    platform,
    category,
    Engagement_Type,
    `Engagement_Sub-Type`,
    summary, 
    event_group_id,
    edit_status, 
    is_deleted,
    deleted_at,
    edit_notes

FROM {{ source('social_media_activity_archive', 'tagged_records')}}

QUALIFY ROW_NUMBER() OVER (PARTITION BY retool_primary_key ORDER BY date_posted DESC) = 1
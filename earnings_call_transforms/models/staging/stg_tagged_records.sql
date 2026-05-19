-- TODO: What tests do we need to enforce here?

{{ config(schema='social_media_activity_archive') }}

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
    edit_notes,
FROM {{ source('social_media_activity_archive', 'tagged_records')}}
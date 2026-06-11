{{ config(schema='social_media_activity_archive') }}

SELECT 
    assignments,
    category,
    corporation,
    date_posted,
    deleted_at,
    edit_notes,
    edit_status, 
    Engagement_Type,
    `Engagement_Sub-Type`,
    event_group_id,
    is_deleted,
    platform,
    post_text,
    product,
    retool_primary_key,
    row_status,
    sector,
    summary, 
    url,
    peer_of

FROM {{ ref('int_tagged_records')}}

WHERE edit_status = "Final"
    AND Engagement_Type != "Not an Engagement"
    AND `Engagement_Sub-Type` != "Not an Engagement"
    AND is_deleted IS NOT TRUE
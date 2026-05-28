-- TODO: Add deduplication, filters ("Not an Engagement", "Deleted", etc.)
-- TODO: Add uniqueness and not null tests on retool_primary_key

{{ config(schema='social_media_activity_archive') }}

SELECT 
    C.assignments,
    B.category,
    B.corporation,
    B.date_posted,
    CAST(NULL AS TIMESTAMP) as deleted_at,
    B.edit_notes,
    B.edit_status, 
    B.Engagement_Type,
    B.`Engagement_Sub-Type`,
    B.event_group_id,
    B.is_deleted,
    B.platform,
    B.post_text,
    C.product,
    B.retool_primary_key,
    'Labeled' as row_status,
    B.sector,
    B.summary, 
    B.url,
    C.peer_of

FROM {{ ref('stg_tagged_records')}} AS B
  
LEFT JOIN {{ ref('stg_corporate_reference') }} AS C 
    ON TRIM(LOWER(C.corporation)) = TRIM(LOWER(B.corporation))
  SELECT 
    assignments,
    corrected_category AS category,
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
    corrected_sector AS sector,
    summary,
    url

FROM {{ ref('int_unvalidated_benchmarking.sql' )}}
{{ config(schema='pressure_monitoring') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT story_id,
        issue_area,
        first_seen_date,
        last_seen_date,
    REPLACE(TRIM(COALESCE(cm.new_category, issue_area)), "’", "'") AS corrected_category

FROM {{ source('zignal_gold', 'story') }} s

LEFT JOIN {{ ref('category_map') }} cm 
    ON TRIM(LOWER(s.issue_area)) = TRIM(LOWER(cm.old_category))
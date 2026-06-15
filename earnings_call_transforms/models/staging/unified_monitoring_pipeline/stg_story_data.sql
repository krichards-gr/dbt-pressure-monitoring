{{ config(schema='pressure_monitoring') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

SELECT story_id,
        -- issue_area,
        first_seen_date, -- This is the first date that this story appeared/was captured (serves as heuristic for publication date)
    REPLACE(TRIM(COALESCE(cm.new_category, issue_area)), "’", "'") AS category -- Grab the first non-null issue/category value, replace curly quote with regular

FROM {{ source('zignal_gold', 'story') }} s

LEFT JOIN {{ ref('category_map') }} cm  -- Join on seed table that maps old/misformatted issues to new/correct ones
    ON TRIM(LOWER(s.issue_area)) = TRIM(LOWER(cm.old_category))
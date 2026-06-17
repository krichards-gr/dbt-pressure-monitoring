{{ config(schema='risk_index_data') }}

WITH
  quarters AS (
    SELECT
      category,
      DATE_TRUNC(DATE(date_posted), QUARTER) AS quarter_start,
      sector,
      CASE
        WHEN Engagement_Type = 'Backlash' THEN 'Backlash'
        ELSE 'Engagement'
        END
        AS type
    FROM {{ ref('mart_tagged_records') }}
    WHERE category IS NOT NULL AND sector IS NOT NULL
  ),
  pivoted_counts AS (
    SELECT
      category,
      sector,
      quarter_start,
      COUNTIF(type = 'Engagement') AS engagement_count,
      COUNTIF(type = 'Backlash') AS backlash_count
    FROM quarters
    GROUP BY category, sector, quarter_start
  ),
  categories AS (
    SELECT category
    FROM
      UNNEST(
        [
          "AI & Technology", "Climate Change & Sustainability",
          "Economic Headwinds", "Gender Equity", "Health Access", "Immigration",
          "LGBTQ+ Equality", "Nutrition & Food Access", "Racial Equity & DEI",
          "Religious & Political Diversity", "Reproductive Rights",
          "Workers' Rights"])
        AS category
  ),
  sectors AS (
    SELECT DISTINCT sector
    FROM {{ ref('mart_tagged_records') }}
    WHERE sector IS NOT NULL
  ),
  all_quarters AS (SELECT DISTINCT quarter_start FROM pivoted_counts),
  grid AS (
    SELECT c.category, s.sector, aq.quarter_start
    FROM categories c
    CROSS JOIN sectors s
    CROSS JOIN all_quarters aq
  )
SELECT
  g.sector,
  g.category,
  g.quarter_start,
  COALESCE(pc.engagement_count, 0) AS engagement_count,
  COALESCE(pc.backlash_count, 0) AS backlash_count
FROM grid g
LEFT JOIN pivoted_counts pc
  ON
    g.category = pc.category
    AND g.sector = pc.sector
    AND g.quarter_start = pc.quarter_start

    WHERE g.quarter_start >= "2025-01-01"
ORDER BY g.quarter_start DESC, g.category, g.sector
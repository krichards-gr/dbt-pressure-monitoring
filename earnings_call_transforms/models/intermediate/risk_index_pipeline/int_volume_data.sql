{{ config(schema='risk_index_data') }}

WITH
  quarter_means AS (
    SELECT
      SPLIT(dataset_name, ' - ')[SAFE_OFFSET(1)] AS category,
      DATE_TRUNC(Date, QUARTER) AS quarter_start,
      ROUND(AVG(m_count), 0) AS weekly_average
    FROM {{ ref('stg_volume_data')}}
    GROUP BY quarter_start, category
    ORDER BY category, quarter_start DESC
  ),
  inter_issue_scores AS (
    SELECT
      category,
      quarter_start,
      weekly_average,
      CASE -- TODO: These hardcoded risk scores need to be made dynamic
        WHEN weekly_average > 500 THEN 4
        WHEN weekly_average >= 300 THEN 3
        WHEN weekly_average >= 100 THEN 2
        WHEN weekly_average < 100 THEN 1
        END AS inter_issue_score
    FROM quarter_means
  ),
  quarterly_lag AS (
    SELECT
      category,
      quarter_start,
      weekly_average,
      inter_issue_score,
      LAG(weekly_average, 1)
        OVER (
          PARTITION BY category
          ORDER BY quarter_start ASC
        ) AS prev_q1,
      LAG(weekly_average, 2)
        OVER (
          PARTITION BY category
          ORDER BY quarter_start ASC
        ) AS prev_q2
    FROM inter_issue_scores
  ),
  calculated_rolling_avg AS (
    SELECT
      category,
      quarter_start,
      weekly_average,
      inter_issue_score,
      (prev_q1 + prev_q2) / 2.0 AS baseline_rolling_avg
    FROM quarterly_lag
  ),
  
percent_change AS (
  SELECT
  category,
  quarter_start,
  weekly_average,
  inter_issue_score,
  ROUND(
    ((weekly_average - baseline_rolling_avg) / baseline_rolling_avg) * 100,
    2) AS percent_change_vs_rolling_avg,

FROM calculated_rolling_avg
),
percent_change_score AS (SELECT
  category,
  quarter_start,
  weekly_average,
  inter_issue_score,
  percent_change_vs_rolling_avg,
  CASE -- TODO: These hardcoded risk scores need to be made dynamic
    WHEN percent_change_vs_rolling_avg > 26 THEN 4
    WHEN percent_change_vs_rolling_avg >= 1 THEN 3
    WHEN percent_change_vs_rolling_avg >= -25 THEN 2
    WHEN percent_change_vs_rolling_avg < -25 THEN 1
  END AS intra_issue_score,

FROM percent_change
),
full_scores AS (
SELECT
  category,
  quarter_start,
  weekly_average,
  percent_change_vs_rolling_avg,
  inter_issue_score,
  intra_issue_score,
  (inter_issue_score + intra_issue_score) / 2.0 AS combined_score

FROM percent_change_score

)
SELECT * FROM (
SELECT
    REPLACE(TRIM(COALESCE(ecm.new_category, fs.category)), "’", "'") AS category,
    quarter_start,
    weekly_average,
    percent_change_vs_rolling_avg,
    inter_issue_score,
    intra_issue_score,
    combined_score

FROM full_scores fs

LEFT JOIN {{ ref('stg_category_map')}} ecm
  ON TRIM(LOWER(fs.category)) = TRIM(LOWER(ecm.old_category))

ORDER BY category, quarter_start DESC
)
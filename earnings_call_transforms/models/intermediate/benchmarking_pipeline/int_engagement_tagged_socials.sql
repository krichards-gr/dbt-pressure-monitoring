-- To re-tag everything after retraining the model, run the below:
-- dbt run -s int_engagement_tagged_socials --full-refresh

{{ config(
    schema='social_media_activity_archive',
    materialized='incremental',
    unique_key='retool_primary_key',
    incremental_strategy='merge'
) }}

{#  ── Tuning knobs ──────────────────────────────────────────────────────────
    Adjust without retraining. Lower gate = more recall. Higher conf = more precision.
    Current operating point: ~87% engagement reclamation, ~18% queue precision.
#}
{% set gate_threshold = 0.25 %}
{% set stage2_conf_threshold = 0.50 %}

-- ═══════════════════════════════════════════════════════════════════════════
-- 0. SOURCE RECORDS — full table on first run, only new records after that
-- ═══════════════════════════════════════════════════════════════════════════
WITH source_records AS (
  SELECT *
  FROM {{ ref('int_issue_tagged_socials') }}
  {% if is_incremental() %}
  WHERE retool_primary_key NOT IN (
    SELECT retool_primary_key FROM {{ this }}
  )
  {% endif %}
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. GENERATE EMBEDDINGS for incoming records
-- ═══════════════════════════════════════════════════════════════════════════
embedded AS (
  SELECT
    retool_primary_key,
    ml_generate_embedding_result AS embedding,
    ml_generate_embedding_status AS embedding_status
  FROM ML.GENERATE_EMBEDDING(
    MODEL `sri-benchmarking-databases.social_media_activity_archive.text_embedding_model`,
    (
      SELECT
        retool_primary_key,
        post_text AS content
      FROM source_records
      WHERE post_text IS NOT NULL
    ),
    STRUCT(TRUE AS flatten_json_output, 768 AS output_dimensionality)
  )
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. COSINE SIMILARITIES to each class centroid
-- ═══════════════════════════════════════════════════════════════════════════
similarities AS (
  SELECT
    e.retool_primary_key,
    c.class,
    1 - ML.DISTANCE(e.embedding, c.centroid, 'COSINE') AS cosine_sim
  FROM embedded e
  CROSS JOIN `sri-benchmarking-databases.social_media_activity_archive.class_centroids` c
  WHERE e.embedding IS NOT NULL
),

embedding_features AS (
  SELECT
    retool_primary_key,
    MAX(IF(class = 'Not an Engagement',        cosine_sim, NULL)) AS sim_not_an_engagement,
    MAX(IF(class = 'Recognition Statement',    cosine_sim, NULL)) AS sim_recognition_statement,
    MAX(IF(class = 'Community Outreach Event', cosine_sim, NULL)) AS sim_community_outreach,
    MAX(IF(class = 'Sharing Stories',          cosine_sim, NULL)) AS sim_sharing_stories,
    MAX(IF(class = 'Employee Event',           cosine_sim, NULL)) AS sim_employee_event,
    MAX(IF(class = 'Corporate Recognition',    cosine_sim, NULL)) AS sim_corporate_recognition,
    MAX(IF(class = 'Donation/Grant',           cosine_sim, NULL)) AS sim_donation_grant,
    MAX(IF(class = 'Advocacy/Lobbying',        cosine_sim, NULL)) AS sim_advocacy_lobbying,
    MAX(IF(class = 'Company Operations',       cosine_sim, NULL)) AS sim_company_operations,
    MAX(IF(class = 'Sponsorship',              cosine_sim, NULL)) AS sim_sponsorship,
    MAX(IF(class = 'Product Line',             cosine_sim, NULL)) AS sim_product_line,
    MAX(IF(class = 'Corporate Issues Report',  cosine_sim, NULL)) AS sim_corporate_issues_report
  FROM similarities
  GROUP BY 1
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. REGEX FEATURES (same cascade logic as training pipeline)
-- ═══════════════════════════════════════════════════════════════════════════
historical_frequencies AS (
  SELECT
    `Engagement_Sub-Type` AS engagement_sub_type,
    COUNT(*) AS historical_record_count
  FROM `sri-benchmarking-databases.social_media_activity_archive.mart_tagged_records`
  WHERE `Engagement_Sub-Type` NOT IN ('Not an Engagement', '', 'N/A', 'Unassigned', 'Backlash')
    AND `Engagement_Sub-Type` IS NOT NULL
  GROUP BY 1
),

matched AS (
  SELECT
    sr.retool_primary_key,
    CASE
      WHEN et.engagement_sub_type = 'Company Policy' THEN 'Company Operations'
      ELSE et.engagement_sub_type
    END AS engagement_sub_type,
    et.precedence,
    et.key_terms
  FROM source_records sr
  INNER JOIN {{ ref('stg_engagement_term_reference') }} et
    ON REGEXP_CONTAINS(sr.post_text, et.key_terms)
),

per_class_flags AS (
  SELECT
    retool_primary_key,
    engagement_sub_type,
    MIN(precedence) AS min_tier
  FROM matched
  GROUP BY 1, 2
),

top_pred AS (
  SELECT
    retool_primary_key,
    hf.engagement_sub_type AS top_regex_prediction,
    ROW_NUMBER() OVER (
      PARTITION BY retool_primary_key
      ORDER BY
        precedence ASC,
        COALESCE(hf.historical_record_count, 0) DESC,
        hf.engagement_sub_type ASC
    ) AS rn
  FROM matched m
  LEFT JOIN historical_frequencies hf
    ON m.engagement_sub_type = hf.engagement_sub_type
),

distinct_class_count AS (
  SELECT retool_primary_key, COUNT(DISTINCT engagement_sub_type) AS n_classes_fired
  FROM matched
  GROUP BY 1
),

matched_terms_agg AS (
  SELECT
    retool_primary_key,
    STRING_AGG(DISTINCT key_terms, ' | ') AS matched_terms
  FROM matched
  GROUP BY 1
),

regex_features AS (
  SELECT
    sr.retool_primary_key,
    COALESCE(tp.top_regex_prediction, 'UNMATCHED')  AS top_regex_prediction,
    COALESCE(dc.n_classes_fired, 0)                  AS n_classes_fired,
    IF(dc.n_classes_fired > 0, 1, 0)                 AS any_regex_fired,

    MAX(IF(pf.engagement_sub_type = 'Recognition Statement',    1, 0)) AS fire_recognition_statement,
    MAX(IF(pf.engagement_sub_type = 'Community Outreach Event', 1, 0)) AS fire_community_outreach,
    MAX(IF(pf.engagement_sub_type = 'Sharing Stories',          1, 0)) AS fire_sharing_stories,
    MAX(IF(pf.engagement_sub_type = 'Employee Event',           1, 0)) AS fire_employee_event,
    MAX(IF(pf.engagement_sub_type = 'Corporate Recognition',    1, 0)) AS fire_corporate_recognition,
    MAX(IF(pf.engagement_sub_type = 'Donation/Grant',           1, 0)) AS fire_donation_grant,
    MAX(IF(pf.engagement_sub_type = 'Advocacy/Lobbying',        1, 0)) AS fire_advocacy_lobbying,
    MAX(IF(pf.engagement_sub_type = 'Company Operations',       1, 0)) AS fire_company_operations,
    MAX(IF(pf.engagement_sub_type = 'Sponsorship',              1, 0)) AS fire_sponsorship,
    MAX(IF(pf.engagement_sub_type = 'Product Line',             1, 0)) AS fire_product_line,
    MAX(IF(pf.engagement_sub_type = 'Corporate Issues Report',  1, 0)) AS fire_corporate_issues_report,

    MAX(IF(pf.engagement_sub_type = 'Recognition Statement'    AND pf.min_tier = 1, 1, 0)) AS tier1_recognition_statement,
    MAX(IF(pf.engagement_sub_type = 'Community Outreach Event' AND pf.min_tier = 1, 1, 0)) AS tier1_community_outreach,
    MAX(IF(pf.engagement_sub_type = 'Sharing Stories'          AND pf.min_tier = 1, 1, 0)) AS tier1_sharing_stories,
    MAX(IF(pf.engagement_sub_type = 'Employee Event'           AND pf.min_tier = 1, 1, 0)) AS tier1_employee_event,
    MAX(IF(pf.engagement_sub_type = 'Corporate Recognition'    AND pf.min_tier = 1, 1, 0)) AS tier1_corporate_recognition,
    MAX(IF(pf.engagement_sub_type = 'Donation/Grant'           AND pf.min_tier = 1, 1, 0)) AS tier1_donation_grant,
    MAX(IF(pf.engagement_sub_type = 'Advocacy/Lobbying'        AND pf.min_tier = 1, 1, 0)) AS tier1_advocacy_lobbying,
    MAX(IF(pf.engagement_sub_type = 'Company Operations'       AND pf.min_tier = 1, 1, 0)) AS tier1_company_operations,
    MAX(IF(pf.engagement_sub_type = 'Sponsorship'              AND pf.min_tier = 1, 1, 0)) AS tier1_sponsorship,
    MAX(IF(pf.engagement_sub_type = 'Product Line'             AND pf.min_tier = 1, 1, 0)) AS tier1_product_line,
    MAX(IF(pf.engagement_sub_type = 'Corporate Issues Report'  AND pf.min_tier = 1, 1, 0)) AS tier1_corporate_issues_report

  FROM source_records sr
  LEFT JOIN per_class_flags pf USING (retool_primary_key)
  LEFT JOIN (SELECT * FROM top_pred WHERE rn = 1) tp USING (retool_primary_key)
  LEFT JOIN distinct_class_count dc USING (retool_primary_key)
  GROUP BY 1, 2, 3, 4
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. ASSEMBLE FEATURE VECTOR (must match training schema exactly)
-- ═══════════════════════════════════════════════════════════════════════════
features AS (
  SELECT
    sr.retool_primary_key,
    sr.platform,
    rf.top_regex_prediction,
    rf.n_classes_fired,
    rf.any_regex_fired,
    rf.fire_recognition_statement,
    rf.fire_community_outreach,
    rf.fire_sharing_stories,
    rf.fire_employee_event,
    rf.fire_corporate_recognition,
    rf.fire_donation_grant,
    rf.fire_advocacy_lobbying,
    rf.fire_company_operations,
    rf.fire_sponsorship,
    rf.fire_product_line,
    rf.fire_corporate_issues_report,
    rf.tier1_recognition_statement,
    rf.tier1_community_outreach,
    rf.tier1_sharing_stories,
    rf.tier1_employee_event,
    rf.tier1_corporate_recognition,
    rf.tier1_donation_grant,
    rf.tier1_advocacy_lobbying,
    rf.tier1_company_operations,
    rf.tier1_sponsorship,
    rf.tier1_product_line,
    rf.tier1_corporate_issues_report,
    ef.sim_not_an_engagement,
    ef.sim_recognition_statement,
    ef.sim_community_outreach,
    ef.sim_sharing_stories,
    ef.sim_employee_event,
    ef.sim_corporate_recognition,
    ef.sim_donation_grant,
    ef.sim_advocacy_lobbying,
    ef.sim_company_operations,
    ef.sim_sponsorship,
    ef.sim_product_line,
    ef.sim_corporate_issues_report
  FROM source_records sr
  LEFT JOIN regex_features rf USING (retool_primary_key)
  LEFT JOIN embedding_features ef USING (retool_primary_key)
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. STAGE 1 — Binary engagement gate
-- ═══════════════════════════════════════════════════════════════════════════
stage1_preds AS (
  SELECT
    retool_primary_key,
    (SELECT prob
     FROM UNNEST(predicted_is_engagement_probs)
     WHERE label = 'engagement') AS p_engagement
  FROM ML.PREDICT(
    MODEL `sri-benchmarking-databases.social_media_activity_archive.stage1_engagement_gate`,
    (SELECT * FROM features)
  )
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. STAGE 2 — Engagement sub-type classifier
-- ═══════════════════════════════════════════════════════════════════════════
stage2_preds AS (
  SELECT
    retool_primary_key,
    predicted_label AS stage2_pred,
    (SELECT prob
     FROM UNNEST(predicted_label_probs)
     ORDER BY prob DESC
     LIMIT 1) AS stage2_top_prob
  FROM ML.PREDICT(
    MODEL `sri-benchmarking-databases.social_media_activity_archive.stage2_engagement_classifier`,
    (SELECT * FROM features)
  )
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. CASCADE LOGIC — two-knob threshold system
-- ═══════════════════════════════════════════════════════════════════════════
cascade AS (
  SELECT
    s1.retool_primary_key,
    s1.p_engagement,
    s2.stage2_pred,
    s2.stage2_top_prob,
    CASE
      WHEN s1.p_engagement    < {{ gate_threshold }}          THEN 'Not an Engagement'
      WHEN s2.stage2_top_prob < {{ stage2_conf_threshold }}   THEN 'Not an Engagement'
      ELSE s2.stage2_pred
    END AS predicted_sub_type
  FROM stage1_preds s1
  JOIN stage2_preds s2 USING (retool_primary_key)
),

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. ENGAGEMENT TYPE LOOKUP from reference table
-- ═══════════════════════════════════════════════════════════════════════════
type_lookup AS (
  SELECT engagement_sub_type, ANY_VALUE(engagement_type) AS engagement_type
  FROM (
    SELECT DISTINCT
      CASE
        WHEN engagement_sub_type = 'Company Policy'    THEN 'Company Operations'
        WHEN engagement_sub_type = 'Observed Holiday'  THEN 'Recognition Statement'
        ELSE engagement_sub_type
      END AS engagement_sub_type,
      engagement_type
    FROM {{ ref('stg_engagement_term_reference') }}
  )
  GROUP BY 1
)

-- ═══════════════════════════════════════════════════════════════════════════
-- 9. FINAL OUTPUT — matches existing column contract + ML metadata
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  sr.assignments,
  sr.category,
  sr.corporation,
  sr.date_posted,
  sr.deleted_at,
  sr.edit_notes,
  sr.edit_status,
  COALESCE(tl.engagement_type, sr.engagement_type)           AS engagement_type,
  COALESCE(c.predicted_sub_type, sr.engagement_sub_type)     AS engagement_sub_type,
  mta.matched_terms,
  sr.event_group_id,
  sr.is_deleted,
  sr.platform,
  sr.post_text,
  sr.product,
  sr.retool_primary_key,
  sr.row_status,
  sr.sector,
  sr.summary,
  sr.url,

  -- ML metadata for analyst review / debugging
  c.p_engagement                  AS ml_engagement_probability,
  c.stage2_pred                   AS ml_raw_prediction,
  c.stage2_top_prob               AS ml_prediction_confidence,
  rf.top_regex_prediction         AS regex_prediction

FROM source_records sr
LEFT JOIN cascade c              USING (retool_primary_key)
LEFT JOIN type_lookup tl         ON c.predicted_sub_type = tl.engagement_sub_type
LEFT JOIN regex_features rf      USING (retool_primary_key)
LEFT JOIN matched_terms_agg mta  USING (retool_primary_key)
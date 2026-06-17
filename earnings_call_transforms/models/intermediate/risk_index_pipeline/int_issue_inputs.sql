{{ config(schema='risk_index_data') }}

-- Generate quarter start date, correct issue categories to match across product lines

SELECT 
  -- Safely parse the timestamp with the specific format
  DATE_TRUNC(DATE(timestamp), QUARTER) AS quarter_start_date,
  timestamp,
  email_address,
  COALESCE(new_category, what_issue_area_do_you_cover) AS category, -- Map to corrections table
  risk_overview,
  key_subtopics,
  political_rhetoric,
  political_rhetoric_rating,
  legislation,
  legislation_rating,
  litigation,
  litigation_rating,
  major_moments,
  major_moments_rating,
  engagement,
  backlash,
  reputational_and_operational_impact,
  reputational_and_operational_impact_rating,
  polarization,
  major_polls,
  polarization_rating,
  volume_drivers,
  predictions_for_q2,
  predictions_for_next_quarter,
  what_you_re_watching,
  end_of_quarter_flags

  FROM {{ ref('stg_issue_inputs')}} ii

  LEFT JOIN {{ ref('stg_category_map')}} cm
    ON TRIM(LOWER(ii.what_issue_area_do_you_cover)) = TRIM(LOWER(cm.old_category))
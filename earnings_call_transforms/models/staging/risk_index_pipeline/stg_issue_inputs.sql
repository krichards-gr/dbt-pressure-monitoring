{{ config(schema='risk_index_data') }}

SELECT 
  -- Safely parse the timestamp with the specific format
  SAFE.PARSE_DATETIME('%m/%d/%Y %H:%M:%S', timestamp) AS timestamp,
  email_address,
  what_issue_area_do_you_cover,
  risk_overview,
  key_subtopics,
  political_rhetoric,
  SAFE_CAST(political_rhetoric_rating AS INT64) AS political_rhetoric_rating,
  legislation,
  SAFE_CAST(legislation_rating AS INT64) AS legislation_rating,
  litigation,
  SAFE_CAST(litigation_rating AS INT64) AS litigation_rating,
  major_moments,
  SAFE_CAST(major_moments_rating AS INT64) AS major_moments_rating,
  engagement,
  backlash,
  reputational_and_operational_impact,
  SAFE_CAST(reputational_and_operational_impact_rating AS INT64) AS reputational_and_operational_impact_rating,
  polarization,
  major_polls,
  SAFE_CAST(polarization_rating AS INT64) AS polarization_rating,
  volume_drivers,
  predictions_for_q2,
  predictions_for_next_quarter,
  what_you_re_watching,
  end_of_quarter_flags

FROM {{ source('risk_index_data', 'external_risk_index_issue_inputs')}}